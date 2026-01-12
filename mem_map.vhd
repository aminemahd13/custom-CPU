library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mem_map is
    port (
        clk        : in  std_logic;
        rst        : in  std_logic;
        mem_addr   : in  unsigned(15 downto 0);
        mem_wdata  : in  std_logic_vector(15 downto 0);
        mem_we     : in  std_logic;
        mem_re     : in  std_logic;
        mem_rdata  : out std_logic_vector(15 downto 0);

        -- TFT framebuffer read port (for display refresh engine)
        fb_rd_addr : in  unsigned(14 downto 0);
        fb_rd_data : out std_logic_vector(15 downto 0);
        tft_use_fb : out std_logic;
        tft_osd_status : out std_logic_vector(15 downto 0);
        
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
    -- ================================================================
    -- 4K Word RAM (0x2000 - 0x2FFF) - Coded for M9K inference
    -- ================================================================
    type ram_type is array (0 to 4095) of std_logic_vector(15 downto 0);
    signal ram : ram_type;  -- No initialization for M9K inference
    
    -- RAM output register (M9K synchronous read - 1 cycle latency)
    signal ram_dout : std_logic_vector(15 downto 0) := (others => '0');

    -- ================================================================
    -- 128x160 RGB565 Framebuffer (0x3000 - 0x7FFF), 20480 words
    -- ================================================================
    constant FB_BASE  : unsigned(15 downto 0) := to_unsigned(16#3000#, 16);
    constant FB_LAST  : unsigned(15 downto 0) := to_unsigned(16#7FFF#, 16);
    constant FB_WORDS : integer := 128 * 160;

    type fb_type is array (0 to FB_WORDS - 1) of std_logic_vector(15 downto 0);
    signal fb_ram : fb_type;

    signal fb_cpu_dout : std_logic_vector(15 downto 0) := (others => '0');
    signal fb_tft_dout : std_logic_vector(15 downto 0) := (others => '0');
    
    -- IO Registers
    signal reg_leds : std_logic_vector(9 downto 0) := (others => '0');
    signal reg_tft_use_fb : std_logic := '0';
    signal reg_tft_osd_status : std_logic_vector(15 downto 0) := (others => '0');

    -- Attribute to force M9K block RAM (Quartus)
    attribute ramstyle : string;
    attribute ramstyle of ram : signal is "M9K";
    attribute ramstyle of fb_ram : signal is "M9K";

    -- 7-seg helper
    function hex7(n : std_logic_vector(3 downto 0)) return std_logic_vector is
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
        return '1' & seg_lo;
    end function;

begin
    -- Drive physical LEDs
    ledr_out <= reg_leds;
    tft_use_fb <= reg_tft_use_fb;
    tft_osd_status <= reg_tft_osd_status;
    fb_rd_data <= fb_tft_dout;

    -- 7-seg shows TFT OSD status:
    --   HEX2: test_id[7:4], HEX1: test_id[3:0], HEX0: state (0=RUN,1=PASS,2=FAIL)
    hex0 <= hex7("00" & reg_tft_osd_status(1 downto 0));
    hex1 <= hex7(reg_tft_osd_status(11 downto 8));
    hex2 <= hex7(reg_tft_osd_status(15 downto 12));
    hex3 <= (others => '1');
    hex4 <= (others => '1');
    hex5 <= (others => '1');

    -- ================================================================
    -- M9K RAM process - synchronous read/write, 1-cycle read latency
    -- ================================================================
    ram_proc: process(clk, rst)
        variable ram_addr : integer range 0 to 4095;
    begin
        if rst = '1' then
            ram_dout <= (others => '0');
        elsif rising_edge(clk) then
            -- Calculate RAM address (offset from 0x2000)
            if to_integer(mem_addr) >= 16#2000# and to_integer(mem_addr) <= 16#2FFF# then
                ram_addr := to_integer(mem_addr) - 16#2000#;
            else
                ram_addr := 0;
            end if;
            
            -- Synchronous write
            if mem_we = '1' then
                if to_integer(mem_addr) >= 16#2000# and to_integer(mem_addr) <= 16#2FFF# then
                    ram(ram_addr) <= mem_wdata;
                end if;
            end if;
            
            -- Synchronous read - data available NEXT cycle
            ram_dout <= ram(ram_addr);
        end if;
    end process ram_proc;

    -- ================================================================
    -- Framebuffer port A (CPU): synchronous read/write, 1-cycle latency
    -- ================================================================
    fb_cpu_proc: process(clk, rst)
        variable fb_addr : integer range 0 to FB_WORDS - 1;
        variable addr_int : integer;
    begin
        if rst = '1' then
            fb_cpu_dout <= (others => '0');
        elsif rising_edge(clk) then
            addr_int := to_integer(mem_addr);

            if mem_addr >= FB_BASE and mem_addr <= FB_LAST then
                fb_addr := addr_int - 16#3000#;
            else
                fb_addr := 0;
            end if;

            if mem_we = '1' then
                if mem_addr >= FB_BASE and mem_addr <= FB_LAST then
                    fb_ram(fb_addr) <= mem_wdata;
                end if;
            end if;

            fb_cpu_dout <= fb_ram(fb_addr);
        end if;
    end process fb_cpu_proc;

    -- ================================================================
    -- Framebuffer port B (TFT): synchronous read, 1-cycle latency
    -- ================================================================
    fb_tft_proc: process(clk, rst)
        variable fb_addr : integer range 0 to FB_WORDS - 1;
    begin
        if rst = '1' then
            fb_tft_dout <= (others => '0');
        elsif rising_edge(clk) then
            fb_addr := to_integer(fb_rd_addr);
            if fb_addr < FB_WORDS then
                fb_tft_dout <= fb_ram(fb_addr);
            else
                fb_tft_dout <= (others => '0');
            end if;
        end if;
    end process fb_tft_proc;

    -- ================================================================
    -- MMIO register write/reset
    -- ================================================================
    mmio_proc: process(clk, rst)
        variable addr_int : integer;
    begin
        if rst = '1' then
            reg_leds <= (0 => '1', others => '0');
            reg_tft_use_fb <= '0';
            reg_tft_osd_status <= x"0100"; -- T01 + RUN (debug default)
        elsif rising_edge(clk) then
            addr_int := to_integer(mem_addr);
            if mem_we = '1' and addr_int = 16#FFFE# then
                reg_leds <= mem_wdata(9 downto 0);
            end if;
            if mem_we = '1' and addr_int = 16#FFFD# then
                reg_tft_use_fb <= mem_wdata(0);
            end if;
            if mem_we = '1' and addr_int = 16#FFFC# then
                reg_tft_osd_status <= mem_wdata;
                reg_leds <= mem_wdata(9 downto 0);
            end if;
        end if;
    end process mmio_proc;

    -- ================================================================
    -- Read mux (COMBINATIONAL): CPU expects data during the cycle
    -- after it asserts mem_re. ram_dout is already a registered
    -- synchronous RAM output (M9K-friendly).
    -- ================================================================
    mem_rdata <=
        ram_dout             when (mem_re = '1' and to_integer(mem_addr) >= 16#2000# and to_integer(mem_addr) <= 16#2FFF#) else
        fb_cpu_dout          when (mem_re = '1' and mem_addr >= FB_BASE and mem_addr <= FB_LAST) else
        reg_tft_osd_status   when (mem_re = '1' and to_integer(mem_addr) = 16#FFFC#) else
        ("000000" & reg_leds) when (mem_re = '1' and to_integer(mem_addr) = 16#FFFE#) else
        ((15 downto 1 => '0') & reg_tft_use_fb) when (mem_re = '1' and to_integer(mem_addr) = 16#FFFD#) else
        (others => '0');

end architecture;
