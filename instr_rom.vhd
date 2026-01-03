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
    
    -- Hardware self-test + slow counter display.
    -- Exercised: RAM write/read, XOR check, ANDI/ADDI/OR, BNE, J, I/O store.
    constant ROM_CONTENT : rom_type := (
        -- 0: R1 <- 0 (counter)
        0  => x"01100000",  -- LDI R1, 0x0000
        -- 1: R2 <- 0x03FF (LED mask)
        1  => x"012003FF",  -- LDI R2, 0x03FF
        -- 2: R3 <- 0x1000 (delay init, also test value)
        2  => x"01301000",  -- LDI R3, 0x1000
        -- 3: R5 <- 0xA55A (RAM test pattern)
        3  => x"0150A55A",  -- LDI R5, 0xA55A
        -- 4: RAM[0x2000] <- R5
        4  => x"41502000",  -- ST  R5, [0x2000]
        -- 5: R6 <- RAM[0x2000]
        5  => x"40602000",  -- LD  R6, [0x2000]
        -- 6: R7 <- R5 xor R6 (error nibble if RAM bad)
        6  => x"22750006",  -- XOR R7, R5, R6
        -- 7: R7 <- R7 & 0x000F
        7  => x"2377000F",  -- ANDI R7, R7, 0x000F

        -- Main loop starts at 8
        -- 8: R3 <- 0x0FFF (reload delay)
        8  => x"01300FFF",  -- LDI R3, 0x0FFF
        -- 9: R4 <- R1
        9  => x"10410000",  -- ADD R4, R1, R0
        -- 10: R4 &= 0x03FF (limit to 10 bits)
        10 => x"234403FF",  -- ANDI R4, R4, 0x03FF
        -- 11: R4 <- R4 OR R7 (embed RAM error nibble)
        11 => x"21440007",  -- OR  R4, R4, R7
        -- 12: LEDS <- R4
        12 => x"4140FFFE",  -- ST  R4, [0xFFFE]
        -- 13: R3 <- R3 - 1
        13 => x"1233FFFF",  -- ADDI R3, R3, -1
        -- 14: if R3 != 0, loop to 13
        14 => x"5103FFFE",  -- BNE R3, R0, -2 (to PC=13)
        -- 15: R1 <- R1 + 1 (increment visible counter)
        15 => x"12110001",  -- ADDI R1, R1, 1
        -- 16: Jump back to 8
        16 => x"5200FFF7",  -- J -9 (to PC=8)

        others => x"00000000" -- NOP padding
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