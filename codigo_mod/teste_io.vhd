--==================================================================
-- Teste Unitário 2: Verificação de Entradas e Saídas
-- Objetivo: Validar a pinagem dos botões KEY e dos LEDs.
-- Comportamento: Pressionar um botão KEY acende um LED correspondente.
--==================================================================
library ieee;
use ieee.std_logic_1164.all;

entity teste_io is
    port (
        KEY  : in  std_logic_vector(3 downto 0);
        LEDR : out std_logic_vector(0 downto 0);
        LEDG : out std_logic_vector(2 downto 0)
    );
end entity teste_io;

architecture rtl of teste_io is
begin
    -- Os botões na DE2-70 são ativos em nível baixo ('0' quando pressionado).
    -- Os LEDs acendem em nível alto ('1').
    -- Portanto, invertemos a lógica do botão.
    LEDR(0) <= not KEY(0);
    LEDG(0) <= not KEY(1);
    LEDG(1) <= not KEY(2);
    LEDG(2) <= not KEY(3);

end architecture rtl;