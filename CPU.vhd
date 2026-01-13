library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity CPU is
    port (
        -- DE10-Lite Clock
        CLOCK_50 : in std_logic;

        -- DE10-Lite Keys (KEY0 is usually Reset)
        KEY      : in std_logic_vector(1 downto 0);

        -- DE10-Lite LEDs
        LEDR     : out std_logic_vector(9 downto 0);

        -- DE10-Lite Arduino Header (used for SPI TFT)
        ARDUINO_IO      : inout std_logic_vector(15 downto 0);
        ARDUINO_RESET_N : in    std_logic;

        -- HEX Displays (Included to prevent compile errors if your QSF expects them)
        -- We won't drive them in this test, so we'll assign them to 'OFF' (all 1s)
        HEX0     : out std_logic_vector(7 downto 0);
        HEX1     : out std_logic_vector(7 downto 0);
        HEX2     : out std_logic_vector(7 downto 0);
        HEX3     : out std_logic_vector(7 downto 0);
        HEX4     : out std_logic_vector(7 downto 0);
        HEX5     : out std_logic_vector(7 downto 0)
    );
end entity CPU;

architecture rtl of CPU is

    -- =========================================================
    -- Component Declarations
    -- =========================================================

    component instr_rom is
        port (
            clk      : in  std_logic;
            rst      : in  std_logic;
            addr     : in  unsigned(15 downto 0);
            data_out : out std_logic_vector(31 downto 0)
        );
    end component;

    component cpu_core is
        port (
            clk         : in  std_logic;
            rst         : in  std_logic;
            pc_out      : out unsigned(15 downto 0);
            instr_in    : in  std_logic_vector(31 downto 0);
            mem_addr    : out unsigned(15 downto 0);
            mem_wdata   : out std_logic_vector(15 downto 0);
            mem_we      : out std_logic;
            mem_re      : out std_logic;
            mem_rdata   : in  std_logic_vector(15 downto 0)
        );
    end component;

    component mem_map is
        port (
            clk        : in  std_logic;
            rst        : in  std_logic;
            mem_addr   : in  unsigned(15 downto 0);
            mem_wdata  : in  std_logic_vector(15 downto 0);
            mem_we     : in  std_logic;
            mem_re     : in  std_logic;
            mem_rdata  : out std_logic_vector(15 downto 0);
            fb_rd_addr : in  unsigned(14 downto 0);
            fb_rd_data : out std_logic_vector(15 downto 0);
            tft_use_fb : out std_logic;
            tft_osd_status : out std_logic_vector(15 downto 0);
            ledr_out   : out std_logic_vector(9 downto 0);
            hex0       : out std_logic_vector(7 downto 0);
            hex1       : out std_logic_vector(7 downto 0);
            hex2       : out std_logic_vector(7 downto 0);
            hex3       : out std_logic_vector(7 downto 0);
            hex4       : out std_logic_vector(7 downto 0);
            hex5       : out std_logic_vector(7 downto 0)
        );
    end component;

    component tft_st7735 is
        generic (
            WIDTH   : integer := 128;
            HEIGHT  : integer := 160;
            SPI_DIV : integer := 4
        );
        port (
            clk : in std_logic;
            rst : in std_logic;
            use_fb  : in  std_logic;
            fb_addr : out unsigned(14 downto 0);
            fb_data : in  std_logic_vector(15 downto 0);
            osd_status : in std_logic_vector(15 downto 0);
            tft_cs_n    : out std_logic;
            tft_reset_n : out std_logic;
            tft_dc      : out std_logic;
            tft_sck     : out std_logic;
            tft_mosi    : out std_logic
        );
    end component;

    -- =========================================================
    -- Internal Signals
    -- =========================================================

    -- Reset signal (Active High internally)
    signal sys_rst       : std_logic;
    signal rst_sync1     : std_logic := '1';
    signal rst_sync2     : std_logic := '1';

    -- CPU <-> ROM Interconnect
    signal cpu_pc        : unsigned(15 downto 0);
    signal cpu_instr     : std_logic_vector(31 downto 0);

    -- CPU <-> Memory Bus Interconnect
    signal bus_addr      : unsigned(15 downto 0);
    signal bus_wdata     : std_logic_vector(15 downto 0);
    signal bus_rdata     : std_logic_vector(15 downto 0);
    signal bus_we        : std_logic;
    signal bus_re        : std_logic;
    
    -- TFT interconnect
    signal tft_fb_addr   : unsigned(14 downto 0);
    signal tft_fb_data   : std_logic_vector(15 downto 0);
    signal tft_use_fb    : std_logic;
    signal tft_osd_status : std_logic_vector(15 downto 0);
    signal tft_cs_n      : std_logic;
    signal tft_reset_n   : std_logic;
    signal tft_dc        : std_logic;
    signal tft_sck       : std_logic;
    signal tft_mosi      : std_logic;
    
    signal arduino_io_drv : std_logic_vector(15 downto 0);

begin

    -- 1. Reset Logic
    -- KEY(0) is active LOW on DE10-Lite. Synchronize to CLOCK_50
    -- to avoid metastability and ensure clean release.
    process(CLOCK_50, KEY(0))
    begin
        if KEY(0) = '0' then
            rst_sync1 <= '1';
            rst_sync2 <= '1';
        elsif rising_edge(CLOCK_50) then
            rst_sync1 <= '0';
            rst_sync2 <= rst_sync1;
        end if;
    end process;

    sys_rst <= rst_sync2;

    -- 3. Instantiate Instruction ROM (Holds the program)
    u_rom: instr_rom
    port map (
        clk      => CLOCK_50,
        rst      => sys_rst,
        addr     => cpu_pc,
        data_out => cpu_instr
    );

    -- 4. Instantiate CPU Core (The Processor)
    u_core: cpu_core
    port map (
        clk       => CLOCK_50,
        rst       => sys_rst,
        pc_out    => cpu_pc,
        instr_in  => cpu_instr,
        mem_addr  => bus_addr,
        mem_wdata => bus_wdata,
        mem_we    => bus_we,
        mem_re    => bus_re,
        mem_rdata => bus_rdata
    );

    -- 5. Instantiate Memory Map (RAM + IO Controller)
    u_mem: mem_map
    port map (
        clk       => CLOCK_50,
        rst       => sys_rst,
        mem_addr  => bus_addr,
        mem_wdata => bus_wdata,
        mem_we    => bus_we,
        mem_re    => bus_re,
        mem_rdata => bus_rdata,
        fb_rd_addr => tft_fb_addr,
        fb_rd_data => tft_fb_data,
        tft_use_fb => tft_use_fb,
        tft_osd_status => tft_osd_status,
        ledr_out  => LEDR,
        hex0      => HEX0,
        hex1      => HEX1,
        hex2      => HEX2,
        hex3      => HEX3,
        hex4      => HEX4,
        hex5      => HEX5
    );

    -- 6. SPI TFT (ST7735-class 1.8" modules) refresh engine
    u_tft: tft_st7735
    port map (
        clk         => CLOCK_50,
        rst         => sys_rst,
        use_fb      => tft_use_fb,
        fb_addr     => tft_fb_addr,
        fb_data     => tft_fb_data,
        osd_status  => tft_osd_status,
        tft_cs_n    => tft_cs_n,
        tft_reset_n => tft_reset_n,
        tft_dc      => tft_dc,
        tft_sck     => tft_sck,
        tft_mosi    => tft_mosi
    );

    -- Arduino header wiring (DE10-Lite): ARDUINO_IO(N) is Arduino pin N
    -- Your wiring:
    --   IO10 <= CS, IO8 <= RESET, IO9 <= DC, IO11 <= MOSI/SDA, IO13 <= SCK
    arduino_drive: process(tft_cs_n, tft_reset_n, tft_dc, tft_mosi, tft_sck)
    begin
        arduino_io_drv <= (others => 'Z');
        arduino_io_drv(10) <= tft_cs_n;     -- IO10 (CS, active low)
        arduino_io_drv(8)  <= tft_reset_n;  -- IO8  (RESET, active low at display pin)
        arduino_io_drv(9)  <= tft_dc;       -- IO9  (AO/DC)
        arduino_io_drv(11) <= tft_mosi;     -- IO11 (MOSI/SDA)
        arduino_io_drv(13) <= tft_sck;      -- IO13 (SCK)
    end process;

    ARDUINO_IO <= arduino_io_drv;

end architecture rtl;
