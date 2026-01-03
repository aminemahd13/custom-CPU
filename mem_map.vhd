library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_map is
    port (
        clk        : in  std_logic;
        mem_addr   : in  unsigned(15 downto 0);
        mem_wdata  : in  std_logic_vector(15 downto 0);
        mem_we     : in  std_logic;
        mem_re     : in  std_logic;
        mem_rdata  : out std_logic_vector(15 downto 0);
        
        -- Board Hardware Connections
        ledr_out   : out std_logic_vector(9 downto 0)
    );
end entity mem_map;

architecture rtl of mem_map is
    -- 4K Word RAM (0x2000 - 0x2FFF)
    type ram_type is array (0 to 4095) of std_logic_vector(15 downto 0);
    signal ram : ram_type := (others => (others => '0'));
    
    -- IO Registers
    signal reg_leds : std_logic_vector(9 downto 0) := (others => '0');

begin
    -- Drive physical LEDs
    ledr_out <= reg_leds;

    process(clk)
        variable addr_int : integer;
    begin
        if rising_edge(clk) then
            addr_int := to_integer(mem_addr);

            -- WRITE LOGIC
            if mem_we = '1' then
                -- RAM Region (0x2000 - 0x2FFF)
                if addr_int >= 16#2000# and addr_int <= 16#2FFF# then
                    ram(addr_int - 16#2000#) <= mem_wdata;
                
                -- MMIO: LEDS (0xFFFE)
                elsif addr_int = 16#FFFE# then
                    reg_leds <= mem_wdata(9 downto 0);
                end if;
            end if;

            -- READ LOGIC (Registered return)
            -- If mem_re is asserted, data appears next cycle
            if mem_re = '1' then
                if addr_int >= 16#2000# and addr_int <= 16#2FFF# then
                    mem_rdata <= ram(addr_int - 16#2000#);
                elsif addr_int = 16#FFFE# then
                    mem_rdata <= "000000" & reg_leds;
                else
                    mem_rdata <= (others => '0');
                end if;
            end if;
        end if;
    end process;

end architecture;