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
    
    -- Simple hardware self-test program exercising RAM, ALU, branches, and I/O.
    -- Addresses are word indices (PC units).
    constant ROM_CONTENT : rom_type := (
        -- 0: R1 <- 0 (counter)
        0  => x"01100000",  -- LDI R1, 0x0000
        -- 1: R2 <- 0x03FF (LED mask)
        1  => x"012003FF",  -- LDI R2, 0x03FF
        -- 2: R5 <- 0xA55A (RAM test pattern)
        2  => x"0150A55A",  -- LDI R5, 0xA55A
        -- 3: RAM[0x2000] <- R5
        3  => x"41502000",  -- ST  R5, [0x2000]
        -- 4: R6 <- RAM[0x2000]
        4  => x"40602000",  -- LD  R6, [0x2000]
        -- 5: R7 <- R5 xor R6 (should be 0 if RAM works)
        5  => x"22750006",  -- XOR R7, R5, R6
        -- 6: R4 <- R1 (copy counter)
        6  => x"10410000",  -- ADD R4, R1, R0
        -- 7: R4 &= 0x03FF (limit to 10 bits for LEDs/HEX)
        7  => x"234403FF",  -- ANDI R4, R4, 0x03FF
        -- 8: LEDS <- R4
        8  => x"4140FFFE",  -- ST  R4, [0xFFFE]
        -- 9: R1 <- R1 + 1 (counter++)
        9  => x"12110001",  -- ADDI R1, R1, 1
        --10: Jump back to 6 (loop)
        10 => x"5200FFFB",  -- J -5 (to PC=6)

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