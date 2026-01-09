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
    type rom_type is array (0 to 255) of std_logic_vector(31 downto 0);
    
    --
    -- COMPREHENSIVE CPU TEST PROGRAM WITH VISUAL FEEDBACK
    --
    -- Display codes on 7-segment (hex):
    --   0x001-0x00F = Test number currently running
    --   0x1XX       = Test XX PASSED (shows briefly, then continues)
    --   0x2XX       = Test XX FAILED (HALTS here!)
    --   0x3FF       = ALL TESTS PASSED! Victory blink!
    --
    -- Tests (15 total):
    --   01: LDI - Load Immediate
    --   02: MV  - Register Move  
    --   03: ADD - Register Addition
    --   04: SUB - Register Subtraction
    --   05: ADDI - Add Immediate
    --   06: AND - Bitwise AND
    --   07: OR  - Bitwise OR
    --   08: XOR - Bitwise XOR
    --   09: ANDI - AND Immediate
    --   0A: SHL - Shift Left
    --   0B: SHR - Shift Right Logical
    --   0C: R0 Hardwired Zero
    --   0D: ST/LD - Memory Store/Load  
    --   0E: LDX/STX - Base+Offset Memory
    --   0F: Negative ADDI test
    -- ================================================================
    
    constant ROM_CONTENT : rom_type := (
        -- ============================================================
        -- TEST 01: LDI (Load Immediate)
        -- ============================================================
        0  => x"01F00001",  -- LDI R15, 0x0001     ; Test 01
        1  => x"41F0FFFE",  -- ST  R15, [0xFFFE]   ; Display "001"
        2  => x"011000AB",  -- LDI R1, 0x00AB      ; R1 = 0xAB
        3  => x"012000AB",  -- LDI R2, 0x00AB      ; Expected
        4  => x"50120004",  -- BEQ R1, R2, +4      ; Pass if equal
        5  => x"01F00201",  -- LDI R15, 0x0201     ; FAIL
        6  => x"41F0FFFE",  -- ST  R15, [0xFFFE]   
        7  => x"FF000000",  -- HALT
        8  => x"01F00101",  -- LDI R15, 0x0101     ; PASS
        9  => x"41F0FFFE",  -- ST  R15, [0xFFFE]   

        -- ============================================================
        -- TEST 02: MV (Register Move)
        -- ============================================================
        10 => x"01F00002",  -- LDI R15, 0x0002     
        11 => x"41F0FFFE",  -- ST  R15, [0xFFFE]   
        12 => x"011000CD",  -- LDI R1, 0x00CD      
        13 => x"02310000",  -- MV  R3, R1          ; R3 = R1
        14 => x"50310004",  -- BEQ R3, R1, +4      
        15 => x"01F00202",  -- FAIL
        16 => x"41F0FFFE",  
        17 => x"FF000000",  
        18 => x"01F00102",  -- PASS
        19 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 03: ADD (5 + 7 = 12)
        -- ============================================================
        20 => x"01F00003",  
        21 => x"41F0FFFE",  
        22 => x"01100005",  -- LDI R1, 5           
        23 => x"01200007",  -- LDI R2, 7           
        24 => x"10310002",  -- ADD R3, R1, R2      ; R3 = 12
        25 => x"0140000C",  -- LDI R4, 12          
        26 => x"50340004",  -- BEQ R3, R4, +4      
        27 => x"01F00203",  -- FAIL
        28 => x"41F0FFFE",  
        29 => x"FF000000",  
        30 => x"01F00103",  -- PASS
        31 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 04: SUB (20 - 8 = 12)
        -- ============================================================
        32 => x"01F00004",  
        33 => x"41F0FFFE",  
        34 => x"01100014",  -- LDI R1, 20          
        35 => x"01200008",  -- LDI R2, 8           
        36 => x"11310002",  -- SUB R3, R1, R2      ; R3 = 12
        37 => x"0140000C",  -- LDI R4, 12          
        38 => x"50340004",  -- BEQ R3, R4, +4      
        39 => x"01F00204",  -- FAIL
        40 => x"41F0FFFE",  
        41 => x"FF000000",  
        42 => x"01F00104",  -- PASS
        43 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 05: ADDI (100 + 55 = 155)
        -- ============================================================
        44 => x"01F00005",  
        45 => x"41F0FFFE",  
        46 => x"01100064",  -- LDI R1, 100         
        47 => x"12210037",  -- ADDI R2, R1, 55     ; R2 = 155
        48 => x"0130009B",  -- LDI R3, 155         
        49 => x"50230004",  -- BEQ R2, R3, +4      
        50 => x"01F00205",  -- FAIL
        51 => x"41F0FFFE",  
        52 => x"FF000000",  
        53 => x"01F00105",  -- PASS
        54 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 06: AND (0xFF & 0x0F = 0x0F)
        -- ============================================================
        55 => x"01F00006",  
        56 => x"41F0FFFE",  
        57 => x"011000FF",  -- LDI R1, 0xFF        
        58 => x"0120000F",  -- LDI R2, 0x0F        
        59 => x"20310002",  -- AND R3, R1, R2      
        60 => x"0140000F",  -- LDI R4, 0x0F        
        61 => x"50340004",  -- BEQ R3, R4, +4      
        62 => x"01F00206",  -- FAIL
        63 => x"41F0FFFE",  
        64 => x"FF000000",  
        65 => x"01F00106",  -- PASS
        66 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 07: OR (0xF0 | 0x0F = 0xFF)
        -- ============================================================
        67 => x"01F00007",  
        68 => x"41F0FFFE",  
        69 => x"011000F0",  -- LDI R1, 0xF0        
        70 => x"0120000F",  -- LDI R2, 0x0F        
        71 => x"21310002",  -- OR  R3, R1, R2      
        72 => x"014000FF",  -- LDI R4, 0xFF        
        73 => x"50340004",  -- BEQ R3, R4, +4      
        74 => x"01F00207",  -- FAIL
        75 => x"41F0FFFE",  
        76 => x"FF000000",  
        77 => x"01F00107",  -- PASS
        78 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 08: XOR (0xFF ^ 0xAA = 0x55)
        -- ============================================================
        79 => x"01F00008",  
        80 => x"41F0FFFE",  
        81 => x"011000FF",  -- LDI R1, 0xFF        
        82 => x"012000AA",  -- LDI R2, 0xAA        
        83 => x"22310002",  -- XOR R3, R1, R2      
        84 => x"01400055",  -- LDI R4, 0x55        
        85 => x"50340004",  -- BEQ R3, R4, +4      
        86 => x"01F00208",  -- FAIL
        87 => x"41F0FFFE",  
        88 => x"FF000000",  
        89 => x"01F00108",  -- PASS
        90 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 09: ANDI (0xABCD & 0x00FF = 0x00CD)
        -- ============================================================
        91 => x"01F00009",  
        92 => x"41F0FFFE",  
        93 => x"0110ABCD",  -- LDI R1, 0xABCD      
        94 => x"233100FF",  -- ANDI R3, R1, 0x00FF (fixed: was 231100FF)
        95 => x"014000CD",  -- LDI R4, 0x00CD      
        96 => x"50340004",  -- BEQ R3, R4, +4      
        97 => x"01F00209",  -- FAIL
        98 => x"41F0FFFE",  
        99 => x"FF000000",  
        100 => x"01F00109",  -- PASS
        101 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0A: SHL (1 << 4 = 16)
        -- ============================================================
        102 => x"01F0000A",  
        103 => x"41F0FFFE",  
        104 => x"01100001",  -- LDI R1, 1          
        105 => x"30210004",  -- SHL R2, R1, 4      
        106 => x"01300010",  -- LDI R3, 16         
        107 => x"50230004",  -- BEQ R2, R3, +4     
        108 => x"01F0020A",  -- FAIL
        109 => x"41F0FFFE",  
        110 => x"FF000000",  
        111 => x"01F0010A",  -- PASS
        112 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0B: SHR (128 >> 3 = 16)
        -- ============================================================
        113 => x"01F0000B",  
        114 => x"41F0FFFE",  
        115 => x"01100080",  -- LDI R1, 128        
        116 => x"31210003",  -- SHR R2, R1, 3      
        117 => x"01300010",  -- LDI R3, 16         
        118 => x"50230004",  -- BEQ R2, R3, +4     
        119 => x"01F0020B",  -- FAIL
        120 => x"41F0FFFE",  
        121 => x"FF000000",  
        122 => x"01F0010B",  -- PASS
        123 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0C: R0 Hardwired Zero (write should be ignored)
        -- ============================================================
        124 => x"01F0000C",  
        125 => x"41F0FFFE",  
        126 => x"010000FF",  -- LDI R0, 0xFF (should be ignored!)
        127 => x"01100000",  -- LDI R1, 0          
        128 => x"50010004",  -- BEQ R0, R1, +4     ; R0 should still be 0
        129 => x"01F0020C",  -- FAIL
        130 => x"41F0FFFE",  
        131 => x"FF000000",  
        132 => x"01F0010C",  -- PASS
        133 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0D: ST/LD Memory (store 0x1234, load back)
        -- ============================================================
        134 => x"01F0000D",  
        135 => x"41F0FFFE",  
        136 => x"01101234",  -- LDI R1, 0x1234     
        137 => x"41102000",  -- ST  R1, [0x2000]   
        138 => x"01100000",  -- LDI R1, 0          ; Clear R1
        139 => x"40202000",  -- LD  R2, [0x2000]   ; Load back into R2 (fixed: was 40212000)
        140 => x"01301234",  -- LDI R3, 0x1234     
        141 => x"50230004",  -- BEQ R2, R3, +4     
        142 => x"01F0020D",  -- FAIL
        143 => x"41F0FFFE",  
        144 => x"FF000000",  
        145 => x"01F0010D",  -- PASS
        146 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0E: LDX/STX Base+Offset (R5=0x2000, [R5+4]=0xBEEF)
        -- ============================================================
        147 => x"01F0000E",  
        148 => x"41F0FFFE",  
        149 => x"01502000",  -- LDI R5, 0x2000     ; base
        150 => x"0110BEEF",  -- LDI R1, 0xBEEF     
        151 => x"43150004",  -- STX R1, [R5+4]     ; store at 0x2004
        152 => x"01100000",  -- LDI R1, 0          
        153 => x"42250004",  -- LDX R2, [R5+4]     ; load from 0x2004
        154 => x"0130BEEF",  -- LDI R3, 0xBEEF     
        155 => x"50230004",  -- BEQ R2, R3, +4     
        156 => x"01F0020E",  -- FAIL
        157 => x"41F0FFFE",  
        158 => x"FF000000",  
        159 => x"01F0010E",  -- PASS
        160 => x"41F0FFFE",  

        -- ============================================================
        -- TEST 0F: ADDI with negative (100 + (-10) = 90)
        -- ============================================================
        161 => x"01F0000F",  
        162 => x"41F0FFFE",  
        163 => x"01100064",  -- LDI R1, 100        
        164 => x"1221FFF6",  -- ADDI R2, R1, -10   ; 0xFFF6 = -10
        165 => x"0130005A",  -- LDI R3, 90         
        166 => x"50230004",  -- BEQ R2, R3, +4     
        167 => x"01F0020F",  -- FAIL
        168 => x"41F0FFFE",  
        169 => x"FF000000",  
        170 => x"01F0010F",  -- PASS
        171 => x"41F0FFFE",  

        -- ============================================================
        -- ALL TESTS PASSED! Victory display: blink 3FF / 000
        -- ============================================================
        172 => x"01E00008",  -- LDI R14, 8         ; blink speed
        173 => x"011003FF",  -- LDI R1, 0x3FF      ; ON pattern (all segs)
        174 => x"01200000",  -- LDI R2, 0x000      ; OFF pattern

        -- Blink loop
        175 => x"4110FFFE",  -- ST R1, [0xFFFE]    ; Show 3FF
        -- Delay ON
        176 => x"01B00000",  -- LDI R11, 0         
        177 => x"01C0FFF6",  -- LDI R12, 0xFFF6 (inner delay counter start)
        178 => x"12CC0001",  -- ADDI R12, R12, 1   ; inner++
        179 => x"51C0FFFE",  -- BNE R12, R0, -2    ; inner loop (~100 iterations)
        180 => x"12BB0001",  -- ADDI R11, R11, 1   ; outer++
        181 => x"51BEFFFB",  -- BNE R11, R14, -5   ; outer loop (8x)
        
        182 => x"4120FFFE",  -- ST R2, [0xFFFE]    ; Show 000
        -- Delay OFF
        183 => x"01B00000",  -- LDI R11, 0         
        184 => x"01C0FFF6",  -- LDI R12, 0xFFF6 (inner delay counter start)
        185 => x"12CC0001",  -- ADDI R12, R12, 1   
        186 => x"51C0FFFE",  -- BNE R12, R0, -2     ; inner loop (~100 iterations)
        187 => x"12BB0001",  -- ADDI R11, R11, 1   
        188 => x"51BEFFFB",  -- BNE R11, R14, -5   

        189 => x"5200FFF1",  -- J -15              ; back to 175

        others => x"00000000"
    );

    -- Force Quartus to implement the ROM in M9K blocks
    signal rom : rom_type := ROM_CONTENT;
    attribute ramstyle : string;
    attribute ramstyle of rom : signal is "M9K";
begin
    process(clk, rst)
    begin
        if rst = '1' then
            data_out <= rom(0);
        elsif rising_edge(clk) then
            if to_integer(addr) < 256 then
                data_out <= rom(to_integer(addr));
            else
                data_out <= (others => '0');
            end if;
        end if;
    end process;
end architecture;
