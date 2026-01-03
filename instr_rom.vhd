library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity instr_rom is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        addr     : in  unsigned(15 downto 0); -- Word index (PC)
        data_out : out std_logic_vector(31 downto 0)
    );
end entity instr_rom;

architecture rtl of instr_rom is
    type rom_type is array (0 to 31) of std_logic_vector(31 downto 0);
    
    -- Visible heartbeat counter with reasonable delay (~1 sec per increment)
    -- 2-level delay: inner 65536 * outer 128 = ~8M iterations ≈ 1.5 seconds at 50MHz
    constant ROM_CONTENT : rom_type := (
        -- Initialization (runs once after reset)
        0  => x"01100000",  -- LDI R1, 0x0000       (visible counter, starts at 0)
        1  => x"01400080",  -- LDI R4, 0x0080       (outer loop limit = 128)

        -- Main loop entry point (PC=2)
        2  => x"4110FFFE",  -- ST  R1, [0xFFFE]     (display R1 on 7-seg)
        3  => x"12110001",  -- ADDI R1, R1, 1       (R1++)
        4  => x"231103FF",  -- ANDI R1, R1, 0x03FF  (mask to 10 bits for display)

        -- 2-level delay loop
        5  => x"01200000",  -- LDI R2, 0            (reset outer counter)
        6  => x"01300000",  -- LDI R3, 0            (reset inner counter)

        -- Inner delay loop (PC=7,8): counts 65536 times
        7  => x"12330001",  -- ADDI R3, R3, 1       (inner++)
        8  => x"5103FFFE",  -- BNE  R3, R0, -2      (if R3!=0, goto PC=7)

        -- Outer delay loop (PC=9,10): counts 128 times
        9  => x"12220001",  -- ADDI R2, R2, 1       (outer++)
        10 => x"5124FFFC",  -- BNE  R2, R4, -4      (if R2!=R4(128), goto PC=7)

        -- Jump back to display next value
        11 => x"5200FFF6",  -- J -10                (goto PC=2)

        others => x"00000000"
    );
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                -- During reset, preload instruction 0 so it's ready when CPU starts
                data_out <= ROM_CONTENT(0);
            elsif to_integer(addr) < 32 then
                data_out <= ROM_CONTENT(to_integer(addr));
            else
                data_out <= (others => '0');
            end if;
        end if;
    end process;
end architecture;