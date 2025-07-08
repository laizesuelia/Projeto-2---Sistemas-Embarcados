--==================================================================
-- Teste Unitário 1: Verificação dos Displays de 7 Segmentos
-- Objetivo: Acender os displays HEX0 e HEX1 para validar a pinagem.
-- Comportamento: HEX0 conta de 0 a 9 lentamente. HEX1 mostra a letra 'd'.
--==================================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity teste_display is
    port (
        CLOCK_50 : in  std_logic;
        KEY      : in  std_logic_vector(0 downto 0); -- Reset
        HEX1     : out std_logic_vector(6 downto 0);
        HEX0     : out std_logic_vector(6 downto 0)
    );
end entity teste_display;

architecture rtl of teste_display is

    -- Sinal de reset
    signal reset : std_logic;

    -- Sinais para o divisor de clock
    constant MAX_COUNT : integer := 25_000_000; -- Contador para ~0.5s (2 Hz)
    signal clk_counter : integer range 0 to MAX_COUNT := 0;
    signal tick_enable : std_logic := '0'; -- Pulso de habilitação

    -- Sinal para o contador do display
    signal display_counter : integer range 0 to 9 := 0;

    -- Função para converter um número para 7 segmentos (Anodo Comum)
    function bin_para_7seg(bin: integer) return std_logic_vector is
    begin
        case bin is
            when 0 => return "1000000"; -- 0
            when 1 => return "1111001"; -- 1
            when 2 => return "0100100"; -- 2
            when 3 => return "0110000"; -- 3
            when 4 => return "0011001"; -- 4
            when 5 => return "0010010"; -- 5
            when 6 => return "0000010"; -- 6
            when 7 => return "1111000"; -- 7
            when 8 => return "0000000"; -- 8
            when 9 => return "0010000"; -- 9
            when others => return "1111111"; -- Apagado
        end case;
    end function;

begin

    reset <= KEY(0); -- Usar KEY0 como reset (ativo em nível baixo)

    -- Divisor de clock para gerar um pulso 'tick_enable' a cada 0.5 segundo
    process(CLOCK_50, reset)
    begin
        if reset = '0' then
            clk_counter <= 0;
            tick_enable <= '0';
        elsif rising_edge(CLOCK_50) then
            if clk_counter = (MAX_COUNT - 1) then
                clk_counter <= 0;
                tick_enable <= '1';
            else
                clk_counter <= clk_counter + 1;
                tick_enable <= '0';
            end if;
        end if;
    end process;

    -- Lógica do contador que avança com o 'tick_enable'
    process(CLOCK_50, reset)
    begin
        if reset = '0' then
            display_counter <= 0;
        elsif rising_edge(CLOCK_50) then
            if tick_enable = '1' then
                if display_counter = 9 then
                    display_counter <= 0;
                else
                    display_counter <= display_counter + 1;
                end if;
            end if;
        end if;
    end process;

    -- Saídas para os displays
    HEX0 <= bin_para_7seg(display_counter); -- Mostra o contador
    HEX1 <= "0100010";                     -- Mostra a letra 'd'

end architecture rtl;