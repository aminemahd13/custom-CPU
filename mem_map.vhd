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
        ledr_out   : out std_logic_vector(9 downto 0);
        hex0       : out std_logic_vector(7 downto 0);
        hex1       : out std_logic_vector(7 downto 0);
        hex2       : out std_logic_vector(7 downto 0);
        hex3       : out std_logic_vector(7 downto 0);
        hex4       : out std_logic_vector(7 downto 0);
        hex5       : out std_logic_vector(7 downto 0)
    );
end entity mem_map;

architecture rtl of mem_map is
    -- 4K Word RAM (0x2000 - 0x2FFF)
    type ram_type is array (0 to 4095) of std_logic_vector(15 downto 0);
    signal ram : ram_type := (others => (others => '0'));

    -- Synchronous RAM read pipeline
    signal ram_addr_reg : integer range 0 to 4095 := 0;
    signal ram_q        : std_logic_vector(15 downto 0) := (others => '0');
    
    -- IO Registers
    signal reg_leds : std_logic_vector(9 downto 0) := (others => '0');

    -- Read pipeline (registered address and data)
    signal last_re    : std_logic := '0';
    signal last_addr  : unsigned(15 downto 0) := (others => '0');
    signal read_data  : std_logic_vector(15 downto 0) := (others => '0');

    -- 7-seg helper
    function hex7(n : std_logic_vector(3 downto 0)) return std_logic_vector is
        -- gfedcba active-low (DE10-Lite segment order)
        variable seg_lo : std_logic_vector(6 downto 0);
    begin
        case n is
            when "0000" => seg_lo := "1000000"; -- 0
            when "0001" => seg_lo := "1111001"; -- 1
            when "0010" => seg_lo := "0100100"; -- 2
            when "0011" => seg_lo := "0110000"; -- 3
            when "0100" => seg_lo := "0011001"; -- 4
            when "0101" => seg_lo := "0010010"; -- 5
            when "0110" => seg_lo := "0000010"; -- 6
            when "0111" => seg_lo := "1111000"; -- 7
            when "1000" => seg_lo := "0000000"; -- 8
            when "1001" => seg_lo := "0010000"; -- 9
            when "1010" => seg_lo := "0001000"; -- A
            when "1011" => seg_lo := "0000011"; -- b
            when "1100" => seg_lo := "1000110"; -- C
            when "1101" => seg_lo := "0100001"; -- d
            when "1110" => seg_lo := "0000110"; -- E
            when others => seg_lo := "0001110"; -- F
        end case;
        return '1' & seg_lo; -- MSB is DP (off=1), segments active low
    end function;

begin
    -- Drive physical LEDs
    ledr_out <= reg_leds;

    -- 7-seg mirrors LED register across HEX0-HEX2 (10-bit value as hex)
    hex0 <= hex7(reg_leds(3 downto 0));
    hex1 <= hex7(reg_leds(7 downto 4));
    hex2 <= hex7("00" & reg_leds(9 downto 8));
    -- Keep unused digits off
    hex3 <= (others => '1');
    hex4 <= (others => '1');
    hex5 <= (others => '1');

    process(clk)
        variable addr_int : integer;
    begin
        if rising_edge(clk) then
            addr_int := to_integer(mem_addr);

            -- Register RAM read address every cycle (synchronous read)
            if addr_int >= 16#2000# and addr_int <= 16#2FFF# then
                ram_addr_reg <= addr_int - 16#2000#;
            else
                ram_addr_reg <= 0;
            end if;

            -- Synchronous RAM read output
            ram_q <= ram(ram_addr_reg);

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

            -- Capture read request for synchronous, one-cycle latency
            last_re   <= mem_re;
            last_addr <= mem_addr;

            if mem_re = '1' then
                if addr_int >= 16#2000# and addr_int <= 16#2FFF# then
                    read_data <= ram_q;
                elsif addr_int = 16#FFFE# then
                    read_data <= "000000" & reg_leds;
                else
                    read_data <= (others => '0');
                end if;
            end if;

            -- Registered output data, valid one cycle after mem_re
            if last_re = '1' then
                mem_rdata <= read_data;
            else
                mem_rdata <= (others => '0');
            end if;
        end if;
    end process;

end architecture;