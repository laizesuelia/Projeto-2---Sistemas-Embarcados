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

    signal contador : integer := 0;
    constant TEMPO_PODE_PASSAR : integer := 5;
    constant TEMPO_ATENCAO     : integer := 2;
    constant TEMPO_PERIGO      : integer := 5;
    constant TEMPO_EMERGENCIA  : integer := 7;

    signal pedestre_esperando : std_logic := '0'; -- sinal p saber se o pedestre apertou o botao
begin

    -- Transições de estado
    process(clk, reset)
    begin
        if reset = '1' then
            estado_atual <= DESLIGADO;
            contador <= 0;
            pedestre_esperando <= '0'; -- ninguem
            
        elsif rising_edge(clk) then
            --Se o semáforo está funcionando normalmente - nem desligado, nem emergência - 
            -- faz o pedido do pedestre se ele apertar o botão.
            if estado_atual /= DESLIGADO and estado_atual /= EMERGENCIA then
                if botao_pedestre = '1' then
                    pedestre_esperando <= '1';
                end if;
            end if;

            if contador > 0 then
                contador <= contador - 1;
            else
                estado_atual <= proximo_estado;

                case proximo_estado is
                    when PODE_PASSAR =>
                        contador <= TEMPO_PODE_PASSAR;
                        pedestre_esperando <= '0';

                    when ATENCAO =>
                        contador <= TEMPO_ATENCAO;

                    when PERIGO =>
                        contador <= TEMPO_PERIGO;

                    when EMERGENCIA =>
                        contador <= TEMPO_EMERGENCIA;

                    when DESLIGADO =>
                        contador <= 0;
                end case;
            end if;
        end if;
    end process;

    -- Lógica de transições
    process(estado_atual, pedestre_esperando, sinal_emergencia, desliga_semaforo)
    begin
        case estado_atual is
            when DESLIGADO =>
                if desliga_semaforo = '0' then
                    proximo_estado <= PODE_PASSAR;
                else
                    proximo_estado <= DESLIGADO;
                end if;

            when PODE_PASSAR =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                elsif pedestre_esperando = '1' then
                    proximo_estado <= ATENCAO;
                else
                    proximo_estado <= PODE_PASSAR;
                end if;

            when ATENCAO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                else
                    proximo_estado <= PERIGO;
                end if;

            when PERIGO =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                elsif sinal_emergencia = '1' then
                    proximo_estado <= EMERGENCIA;
                else
                    proximo_estado <= PODE_PASSAR;
                end if;

            when EMERGENCIA =>
                if desliga_semaforo = '1' then
                    proximo_estado <= DESLIGADO;
                else
                    proximo_estado <= PODE_PASSAR;
                end if;
        end case;
    end process;

    -- Saídas dos LEDs
    led_pode_passar <= '1' when estado_atual = PODE_PASSAR else '0';
    led_atencao     <= '1' when estado_atual = ATENCAO     else '0';
    led_perigo      <= '1' when estado_atual = PERIGO      else '0';
    led_sistema     <= '0' when estado_atual = DESLIGADO   else '1'; -- só fica desligado se o estado for DESLIGADO

    -- primeiro display mostra código do estado 
    display1 <= "1000000" when estado_atual = PODE_PASSAR else 			--  "P"
                "1111001" when estado_atual = ATENCAO     else 			--  "A"
                "0110000" when estado_atual = PERIGO      else 			--  "E"
                "0000110" when estado_atual = EMERGENCIA  else 			--  "H"
                "1111111"; -- Desligado (apagado)

    -- segundo display mostra contador 
    display2 <= "1111110" when contador = 1 else  -- "1"
                "1101101" when contador = 2 else  -- "2"
                "1111001" when contador = 3 else  -- "3"
                "0110011" when contador = 4 else  -- "4"
                "1011011" when contador = 5 else  -- "5"
                "0000001"; -- Zero ou apagado

end architecture;
