library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instr_rom is
    port (
        clk      : in  std_logic;
        addr     : in  unsigned(15 downto 0); -- Word index (PC)
        data_out : out std_logic_vector(31 downto 0)
    );
end entity instr_rom;

architecture rtl of instr_rom is
    type rom_type is array (0 to 15) of std_logic_vector(31 downto 0);
    
    constant ROM_CONTENT : rom_type := (
        -- 0: LDI R1, 0x03FF  (Load all 10 LEDs mask)
        0 => x"011003FF",
        
        -- 1: ST R1, [0xFFFE] (Store R1 to LEDS address)
        1 => x"4110FFFE",
        
        -- 2: J -1            (Infinite loop: jump back 1 word relative to next PC)
        -- Note: PC is incremented before J executes, so J -1 keeps it here.
        2 => x"5200FFFF",
        
        others => x"00000000" -- NOP
    );
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronous read: data valid 1 cycle after addr
            if to_integer(addr) < 16 then
                data_out <= ROM_CONTENT(to_integer(addr));
            else
                data_out <= (others => '0');
            end if;
        end if;
    end process;
end architecture;