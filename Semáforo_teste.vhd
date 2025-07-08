library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity semaforo_pedestre is
    port (
        clk               : in std_logic;
        reset             : in std_logic;
        botao_pedestre    : in std_logic;
        sinal_emergencia  : in std_logic;
        desliga_semaforo  : in std_logic;

        led_pode_passar   : out std_logic; -- verde
        led_atencao       : out std_logic; -- amarelo
        led_perigo        : out std_logic; -- vermelho
        led_sistema       : out std_logic; -- led p indicar sistema ativo

        display1          : out std_logic_vector(6 downto 0);
        display2          : out std_logic_vector(6 downto 0)
    );
end entity;

architecture behav of semaforo_pedestre is

    type estado_tipo is (DESLIGADO, PODE_PASSAR, ATENCAO, PERIGO, EMERGENCIA);
    signal estado_atual, proximo_estado : estado_tipo;

    -- CORREÇÃO: Usar um sinal para o contador do tempo em segundos.
    -- O clock da placa é muito rápido (ex: 50MHz), precisamos de um contador maior
    -- para gerar um pulso de 1 segundo.
    signal contador_1s   : integer range 0 to 50000000 := 0; -- Assumindo clock de 50MHz
    signal contador_tempo: integer range 0 to 10      := 0;
    
    -- Ajustado para um clock de 50MHz. Para simulação, pode usar um valor menor.
    constant CLK_FREQ_HZ : integer := 50000000; 

    constant TEMPO_PODE_PASSAR : integer := 5;
    constant TEMPO_ATENCAO     : integer := 2;
    constant TEMPO_PERIGO      : integer := 5;
    constant TEMPO_EMERGENCIA  : integer := 7;

    signal pedestre_esperando : std_logic := '0';

begin

    -- Processo 1: REGISTRADOR DE ESTADO (Lógica Síncrona)
    -- A única tarefa dele é atualizar o estado atual a cada batida do clock.
    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESLIGADO;
            pedestre_esperando <= '0';
        elsif rising_edge(clk) then
            estado_atual <= proximo_estado;
            
            -- Registra o pedido do pedestre se o botão for pressionado
            if botao_pedestre = '1' then
                pedestre_esperando <= '1';
            end if;
            
            -- Limpa o pedido do pedestre quando o sinal fica vermelho para ele (verde para carros)
            if proximo_estado = PODE_PASSAR then
                pedestre_esperando <= '0';
            end if;
        end if;
    end process;
    
    
    -- Processo 2: CONTADOR DE TEMPO (Lógica Síncrona)
    -- Gera um pulso de 1 segundo e decrementa o contador de tempo dos estados.
    process(clk, reset)
    begin
        if reset = '1' then
            contador_1s <= 0;
            contador_tempo <= 0;
        elsif rising_edge(clk) then
            -- Lógica para criar um contador de 1 segundo a partir do clock da placa
            if contador_1s = CLK_FREQ_HZ - 1 then
                contador_1s <= 0;
                -- A cada segundo, decrementa o contador principal
                if contador_tempo > 0 then
                    contador_tempo <= contador_tempo - 1;
                end if;
            else
                contador_1s <= contador_1s + 1;
            end if;

            -- CORREÇÃO: Carrega o tempo correto quando o estado MUDA.
            -- Se o estado atual é diferente do próximo, significa que uma transição ocorreu.
            if estado_atual /= proximo_estado then
                case proximo_estado is
                    when PODE_PASSAR => contador_tempo <= TEMPO_PODE_PASSAR;
                    when ATENCAO     => contador_tempo <= TEMPO_ATENCAO;
                    when PERIGO      => contador_tempo <= TEMPO_PERIGO;
                    when EMERGENCIA  => contador_tempo <= TEMPO_EMERGENCIA;
                    when DESLIGADO   => contador_tempo <= 0;
                end case;
            end if;
        end if;
    end process;


    -- Processo 3: LÓGICA DE TRANSIÇÃO (Lógica Combinacional)
    -- Decide qual será o próximo estado baseado no estado atual e nas entradas.
    -- CORREÇÃO: Agora é sensível ao contador_tempo para transições baseadas no tempo.
    process(estado_atual, pedestre_esperando, sinal_emergencia, desliga_semaforo, contador_tempo)
    begin
        -- Por padrão, o próximo estado é o estado atual (fica parado)
        proximo_estado <= estado_atual; 

        case estado_atual is
            when DESLIGADO =>
                if desliga_semaforo = '0' then
                    proximo_estado <= PODE_PASSAR;
                end if;

            when PODE_PASSAR =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                -- CORREÇÃO: Transição quando o tempo acaba E o pedestre pediu
                elsif contador_tempo = 0 and pedestre_esperando = '1' then
                    proximo_estado <= ATENCAO;
                -- CORREÇÃO: Se o tempo acabar mas ninguém pediu, reinicia o tempo do verde
                elsif contador_tempo = 0 and pedestre_esperando = '0' then
                    proximo_estado <= PODE_PASSAR;
                end if;

            when ATENCAO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                -- CORREÇÃO: Transição apenas quando o tempo acaba
                elsif contador_tempo = 0 then
                    proximo_estado <= PERIGO;
                end if;

            when PERIGO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                -- CORREÇÃO: Transição apenas quando o tempo acaba
                elsif contador_tempo = 0 then
                    proximo_estado <= PODE_PASSAR;
                end if;

            when EMERGENCIA =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                -- CORREÇÃO: Só sai da emergência se o sinal for desativado
                elsif sinal_emergencia = '0' then
                    proximo_estado <= PODE_PASSAR;
                end if;
        end case;
    end process;

    -- SAÍDAS (Lógica Combinacional)
    
    led_pode_passar <= '1' when estado_atual = PODE_PASSAR else '0';
    led_atencao     <= '1' when estado_atual = ATENCAO else '0';
    -- CORREÇÃO: A luz de perigo também deve acender na emergência
    led_perigo      <= '1' when estado_atual = PERIGO or estado_atual = EMERGENCIA else '0';
    led_sistema     <= '0' when estado_atual = DESLIGADO else '1';

    -- Display 1: Mostra o estado atual
    display1 <= "0110001" when estado_atual = PODE_PASSAR else  -- "P"
                "1000000" when estado_atual = ATENCAO   else  -- "A"
                "1000110" when estado_atual = PERIGO    else  -- "E"
                "1000111" when estado_atual = EMERGENCIA else  -- "H"
                "1111111"; -- Apagado

    -- Display 2: Mostra o contador de tempo
    -- CORREÇÃO: Usando 'case' para cobrir todos os valores e ser mais legível
    process(contador_tempo)
    begin
        case contador_tempo is
            when 0      => display2 <= "1000000"; -- "0"
            when 1      => display2 <= "1111001"; -- "1"
            when 2      => display2 <= "0100100"; -- "2"
            when 3      => display2 <= "0110000"; -- "3"
            when 4      => display2 <= "0011001"; -- "4"
            when 5      => display2 <= "0010010"; -- "5"
            when 6      => display2 <= "0000010"; -- "6"
            when 7      => display2 <= "1111000"; -- "7"
            when 8      => display2 <= "0000000"; -- "8"
            when 9      => display2 <= "0010000"; -- "9"
            when others => display2 <= "1111111"; -- Apagado
        end case;
    end process;

end architecture;