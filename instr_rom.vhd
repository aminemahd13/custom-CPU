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
    type rom_type is array (0 to 31) of std_logic_vector(31 downto 0);
    
    -- Minimal visible heartbeat counter with a very, very long delay.
    constant ROM_CONTENT : rom_type := (
        -- 0: R1 <- 1 (visible counter)
        0  => x"01100001",  -- LDI R1, 0x0001
        -- 1: R2 <- 0 (outer delay counter)
        1  => x"01200000",  -- LDI R2, 0
        -- 2: R3 <- 0 (inner delay counter)
        2  => x"01300000",  -- LDI R3, 0
        -- 3: R5 <- 0 (outermost delay counter)
        3  => x"01500000",  -- LDI R5, 0

        -- Loop entry
        4  => x"4140FFFE",  -- ST  R4, [0xFFFE] (display current R4)
        5  => x"12110001",  -- ADDI R1, R1, 1        (R1++)
        6  => x"10410000",  -- ADD  R4, R1, R0       (R4 = R1)
        7  => x"234403FF",  -- ANDI R4, R4, 0x03FF   (mask to 10 bits)
        
        -- 3-level nested delay loop
        8  => x"12330001",  -- ADDI R3, R3, 1       (inner_delay++)
        9  => x"5103FFFE",  -- BNE  R3, R0, -2       (loop inner_delay at 8)
        10 => x"12220001",  -- ADDI R2, R2, 1       (outer_delay++)
        11 => x"5102FFFA",  -- BNE  R2, R0, -6       (loop outer_delay at 6 - error in comment, should be 8)
        12 => x"12550001",  -- ADDI R5, R5, 1       (outermost_delay++)
        13 => x"5105FFFA",  -- BNE  R5, R0, -6       (loop outermost_delay at 8)

        14 => x"5200FFF5",  -- J   -11               (to PC=4)

        others => x"00000000"
    );
begin
    process(clk)
    begin
        if rising_edge(clk) then
            -- Synchronous read: data valid 1 cycle after addr
            if to_integer(addr) < 32 then
                data_out <= ROM_CONTENT(to_integer(addr));
            else
                data_out <= (others => '0');
            end if;
        end if;
    end process;
end architecture;