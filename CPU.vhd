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
    -- (Must match the entity names in the other files)
    -- =========================================================

    component instr_rom is
        port (
            clk      : in  std_logic;
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
            mem_addr   : in  unsigned(15 downto 0);
            mem_wdata  : in  std_logic_vector(15 downto 0);
            mem_we     : in  std_logic;
            mem_re     : in  std_logic;
            mem_rdata  : out std_logic_vector(15 downto 0);
            ledr_out   : out std_logic_vector(9 downto 0);
            hex0       : out std_logic_vector(7 downto 0);
            hex1       : out std_logic_vector(7 downto 0);
            hex2       : out std_logic_vector(7 downto 0);
            hex3       : out std_logic_vector(7 downto 0);
            hex4       : out std_logic_vector(7 downto 0);
            hex5       : out std_logic_vector(7 downto 0)
        );
    end component;

    -- =========================================================
    -- Internal Signals
    -- =========================================================

    -- Reset signal (Active High internally)
    signal sys_rst       : std_logic;

    -- CPU <-> ROM Interconnect
    signal cpu_pc        : unsigned(15 downto 0);
    signal cpu_instr     : std_logic_vector(31 downto 0);

    -- CPU <-> Memory Bus Interconnect
    signal bus_addr      : unsigned(15 downto 0);
    signal bus_wdata     : std_logic_vector(15 downto 0);
    signal bus_rdata     : std_logic_vector(15 downto 0);
    signal bus_we        : std_logic;
    signal bus_re        : std_logic;

begin

    -- 1. Reset Logic
    -- KEY(0) is active LOW on DE10-Lite (0 when pressed).
    -- We invert it so sys_rst is active HIGH (1 = Reset), which our CPU expects.
    sys_rst <= not KEY(0);

    -- 3. Instantiate Instruction ROM (Holds the program)
    u_rom: instr_rom
    port map (
        clk      => CLOCK_50,
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
        mem_addr  => bus_addr,
        mem_wdata => bus_wdata,
        mem_we    => bus_we,
        mem_re    => bus_re,
        mem_rdata => bus_rdata,
        ledr_out  => LEDR,
        hex0      => HEX0,
        hex1      => HEX1,
        hex2      => HEX2,
        hex3      => HEX3,
        hex4      => HEX4,
        hex5      => HEX5
    );

end architecture rtl;