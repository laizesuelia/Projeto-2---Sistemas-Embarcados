library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity semaforo_pedestre_corrigido is
    port (
        -- Entradas Globais
        clk              : in  std_logic; -- Clock de 50MHz da placa
        reset_n          : in  std_logic; -- Reset ativo em baixo (KEY0)

        -- Entradas de Controle
        botao_pedestre_n : in  std_logic; -- Botão de pedestre ativo em baixo (KEY1)
        sinal_emergencia : in  std_logic; -- Interruptor para modo de emergência (SW1)
        desliga_semaforo : in  std_logic; -- Interruptor para desligar o sistema (SW0)

        -- Saídas para LEDs
        led_pode_passar  : out std_logic; -- Verde (LEDG)
        led_atencao      : out std_logic; -- Amarelo (LEDR)
        led_perigo       : out std_logic; -- Vermelho (LEDR)
        led_sistema      : out std_logic; -- Sistema ativo (LEDG)

        -- Saídas para Displays de 7 Segmentos
        display1         : out std_logic_vector(6 downto 0); -- Mostra o estado (HEX1)
        display2         : out std_logic_vector(6 downto 0)  -- Mostra o contador (HEX0)
    );
end entity semaforo_pedestre_corrigido;

architecture behavioral of semaforo_pedestre_corrigido is

    -- Definição da Máquina de Estados Finitos (FSM)
    type estado_tipo is (S_DESLIGADO, S_PODE_PASSAR, S_ATENCAO, S_PERIGO, S_EMERGENCIA);
    signal estado_atual, proximo_estado : estado_tipo;

    -- Constantes de tempo para cada estado (em segundos)
    constant TEMPO_PODE_PASSAR : integer := 5;
    constant TEMPO_ATENCAO     : integer := 2;
    constant TEMPO_PERIGO      : integer := 5;
    constant TEMPO_EMERGENCIA  : integer := 7;

    -- Sinais internos
    signal contador_tempo     : integer range 0 to 15;
    signal tick_1hz           : std_logic; -- Pulso de 1Hz gerado pelo prescaler
    signal pedestre_req_pulse : std_logic; -- Pulso limpo de 1 ciclo gerado pelo debouncer

    --------------------------------------------------------------------
    -- Função Decodificadora para Display de 7 Segmentos (Ativo em Baixo)
    -- Converte um inteiro (0-15) em um padrão para o display.
    -- Mapeamento: (g, f, e, d, c, b, a)
    --------------------------------------------------------------------
    function to_7seg(valor : integer) return std_logic_vector is
    begin
        case valor is
            when 0      => return "1000000"; -- 0
            when 1      => return "1111001"; -- 1
            when 2      => return "0100100"; -- 2
            when 3      => return "0110000"; -- 3
            when 4      => return "0011001"; -- 4
            when 5      => return "0010010"; -- 5
            when 6      => return "0000010"; -- 6
            when 7      => return "1111000"; -- 7
            when 8      => return "0000000"; -- 8
            when 9      => return "0010000"; -- 9
            when 10     => return "0001000"; -- A (Atenção)
            when 11     => return "0000110"; -- E (Perigo/Emergência)
            when 12     => return "0001100"; -- P (Pode Passar)
            when others => return "1111111"; -- Display apagado
        end case;
    end function to_7seg;

begin

    --------------------------------------------------------------------
    -- Processo 1: Prescaler de Clock (Divisor de Frequência)
    -- Gera um pulso de 1 ciclo de clock ('tick_1hz') a cada segundo.
    -- F_clk = 50MHz, então 1 segundo = 50,000,000 ciclos.
    --------------------------------------------------------------------
    process(clk, reset_n)
        constant CONTAGEM_MAX_1HZ : integer := 50_000_000 - 1;
        variable contador_clk : integer range 0 to CONTAGEM_MAX_1HZ;
    begin
        if reset_n = '0' then
            contador_clk := 0;
            tick_1hz <= '0';
        elsif rising_edge(clk) then
            if contador_clk = CONTAGEM_MAX_1HZ then
                contador_clk := 0;
                tick_1hz <= '1';
            else
                contador_clk := contador_clk + 1;
                tick_1hz <= '0';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Processo 2: Debouncer para o Botão de Pedestre
    -- Filtra o ruído mecânico e gera um pulso limpo de 1 ciclo.
    --------------------------------------------------------------------
    process(clk, reset_n)
        -- Registrador de deslocamento para filtrar o sinal por ~10ms
        -- 50MHz * 10ms = 500,000. Tamanho 20 é suficiente e mais leve.
        constant DEBOUNCE_STAGES : integer := 20;
        signal shift_reg : std_logic_vector(DEBOUNCE_STAGES-1 downto 0);
        signal prev_state : std_logic;
    begin
        if reset_n = '0' then
            shift_reg <= (others => '1');
            prev_state <= '1';
            pedestre_req_pulse <= '0';
        elsif rising_edge(clk) then
            -- Desloca o estado atual do botão para o registrador
            shift_reg <= shift_reg(DEBOUNCE_STAGES-2 downto 0) & botao_pedestre_n;

            -- Gera o pulso na transição de não pressionado para pressionado estável
            if shift_reg = (others => '0') and prev_state = '1' then
                pedestre_req_pulse <= '1';
            else
                pedestre_req_pulse <= '0';
            end if;

            -- Armazena o estado filtrado anterior
            if shift_reg = (others => '0') then
                prev_state <= '0';
            elsif shift_reg = (others => '1') then
                prev_state <= '1';
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Processo 3: Lógica Síncrona da FSM (Atualização de Estado e Registros)
    -- Este processo atualiza o estado atual e o contador de tempo.
    --------------------------------------------------------------------
    process(clk, reset_n)
    begin
        if reset_n = '0' then
            estado_atual <= S_DESLIGADO;
            contador_tempo <= 0;
        elsif rising_edge(clk) then
            -- O contador de tempo só decrementa no tick de 1Hz
            if tick_1hz = '1' then
                if contador_tempo > 0 then
                    contador_tempo <= contador_tempo - 1;
                end if;
            end if;

            -- A transição de estado ocorre quando o contador chega a zero
            if contador_tempo = 0 then
                estado_atual <= proximo_estado;
                -- Carrega o valor do contador para o próximo estado
                case proximo_estado is
                    when S_PODE_PASSAR => contador_tempo <= TEMPO_PODE_PASSAR;
                    when S_ATENCAO     => contador_tempo <= TEMPO_ATENCAO;
                    when S_PERIGO      => contador_tempo <= TEMPO_PERIGO;
                    when S_EMERGENCIA  => contador_tempo <= TEMPO_EMERGENCIA;
                    when S_DESLIGADO   => contador_tempo <= 0;
                end case;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- Processo 4: Lógica Combinacional da FSM (Cálculo do Próximo Estado)
    -- Este processo determina qual será o próximo estado com base nas entradas.
    --------------------------------------------------------------------
    process(estado_atual, pedestre_req_pulse, sinal_emergencia, desliga_semaforo)
    begin
        -- Por padrão, mantém o estado atual
        proximo_estado <= estado_atual;

        case estado_atual is
            when S_DESLIGADO =>
                if desliga_semaforo = '0' then
                    proximo_estado <= S_PODE_PASSAR;
                end if;

            when S_PODE_PASSAR =>
                if desliga_semaforo = '1' then
                    proximo_estado <= S_DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= S_EMERGENCIA;
                elsif pedestre_req_pulse = '1' then
                    proximo_estado <= S_ATENCAO;
                end if;

            when S_ATENCAO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= S_DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= S_EMERGENCIA;
                else
                    proximo_estado <= S_PERIGO;
                end if;

            when S_PERIGO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= S_DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= S_EMERGENCIA;
                else
                    proximo_estado <= S_PODE_PASSAR;
                end if;

            when S_EMERGENCIA =>
                if desliga_semaforo = '1' then
                    proximo_estado <= S_DESLIGADO;
                elsif sinal_emergencia = '0' then
                    -- Melhoria de segurança: transita para PERIGO antes de voltar ao normal
                    proximo_estado <= S_PERIGO;
                end if;
        end case;
    end process;

    --------------------------------------------------------------------
    -- Lógica de Saída (Atribuições Concorrentes)
    --------------------------------------------------------------------
    -- Saídas dos LEDs (ativos em alto)
    led_pode_passar <= '1' when estado_atual = S_PODE_PASSAR else '0';
    led_atencao     <= '1' when estado_atual = S_ATENCAO or estado_atual = S_EMERGENCIA else '0'; -- Amarelo pisca na emergência
    led_perigo      <= '1' when estado_atual = S_PERIGO else '0';
    led_sistema     <= '1' when estado_atual /= S_DESLIGADO else '0';

    -- Saídas dos Displays (ativos em baixo)
    display1 <= to_7seg(12) when estado_atual = S_PODE_PASSAR else  -- 'P'
                to_7seg(10) when estado_atual = S_ATENCAO     else  -- 'A'
                to_7seg(11) when estado_atual = S_PERIGO      else  -- 'E'
                to_7seg(11) when estado_atual = S_EMERGENCIA  else  -- 'E' de Emergência
                "1111111"; -- Apagado

    display2 <= to_7seg(contador_tempo);

end architecture behavioral;