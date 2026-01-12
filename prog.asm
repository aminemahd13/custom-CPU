-- ============================================================
-- CPU + TFT DIAGNOSTIC ROM SOURCE
--
-- TFT MMIO:
--   0xFFFD: TFT framebuffer enable (bit0)
--   0xFFFC: TFT OSD status word
--           [15:8] = test_id (hex on-screen)
--           [1:0]  = state: 00 RUN, 01 PASS, 10 FAIL
--
-- Framebuffer:
--   0x3000 - 0x7FFF (128*160 RGB565)
-- ============================================================

START:
    -- Enable framebuffer mode (display starts in internal color-bar mode after reset)
    LDI R1, 1
    ST  R1, [0xFFFD]

    -- OSD: T00 UNKN / RUN
    LDI R15, 0x0000
    ST  R15, [0xFFFC]

    -- Clear framebuffer to black
    LDI R5, 0x3000
    LDI R6, 0x5000
    LDI R7, 0
CLR_FB:
    STX R7, [R5 + 0]
    ADDI R5, R5, 1
    ADDI R6, R6, -1
    BNE  R6, R0, CLR_FB

    -- Corner pixels (sanity for addressing)
    LDI R7, 0xF800
    ST  R7, [0x3000]  -- top-left (red)
    LDI R7, 0x07E0
    ST  R7, [0x307F]  -- top-right (green)
    LDI R7, 0x001F
    ST  R7, [0x7F80]  -- bottom-left (blue)
    LDI R7, 0xFFFF
    ST  R7, [0x7FFF]  -- bottom-right (white)

    -- Horizontal white line at y=20 (addr 0x3000 + 20*128 = 0x3A00)
    LDI R5, 0x3A00
    LDI R6, 128
    LDI R7, 0xFFFF
LINE20:
    STX R7, [R5 + 0]
    ADDI R5, R5, 1
    ADDI R6, R6, -1
    BNE  R6, R0, LINE20

-- ============================================================
-- TEST 01: LDI
-- ============================================================
TEST_01:
    LDI R15, 0x0100
    ST  R15, [0xFFFC]
    LDI R1, 0x00AB
    LDI R2, 0x00AB
    BEQ R1, R2, PASS_01
FAIL_01:
    LDI R15, 0x0102
    ST  R15, [0xFFFC]
    HALT
PASS_01:
    LDI R15, 0x0101
    ST  R15, [0xFFFC]
    LDI R11, 8
D01_O:
    LDI R12, 0
D01_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D01_I
    ADDI R11, R11, -1
    BNE  R11, R0, D01_O

-- ============================================================
-- TEST 02: MV
-- ============================================================
TEST_02:
    LDI R15, 0x0200
    ST  R15, [0xFFFC]
    LDI R1, 0x00CD
    MV  R3, R1
    BEQ R3, R1, PASS_02
FAIL_02:
    LDI R15, 0x0202
    ST  R15, [0xFFFC]
    HALT
PASS_02:
    LDI R15, 0x0201
    ST  R15, [0xFFFC]
    LDI R11, 8
D02_O:
    LDI R12, 0
D02_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D02_I
    ADDI R11, R11, -1
    BNE  R11, R0, D02_O

-- ============================================================
-- TEST 03: ADD
-- ============================================================
TEST_03:
    LDI R15, 0x0300
    ST  R15, [0xFFFC]
    LDI R1, 5
    LDI R2, 7
    ADD R3, R1, R2
    LDI R4, 12
    BEQ R3, R4, PASS_03
FAIL_03:
    LDI R15, 0x0302
    ST  R15, [0xFFFC]
    HALT
PASS_03:
    LDI R15, 0x0301
    ST  R15, [0xFFFC]
    LDI R11, 8
D03_O:
    LDI R12, 0
D03_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D03_I
    ADDI R11, R11, -1
    BNE  R11, R0, D03_O

-- ============================================================
-- TEST 04: SUB
-- ============================================================
TEST_04:
    LDI R15, 0x0400
    ST  R15, [0xFFFC]
    LDI R1, 20
    LDI R2, 8
    SUB R3, R1, R2
    LDI R4, 12
    BEQ R3, R4, PASS_04
FAIL_04:
    LDI R15, 0x0402
    ST  R15, [0xFFFC]
    HALT
PASS_04:
    LDI R15, 0x0401
    ST  R15, [0xFFFC]
    LDI R11, 8
D04_O:
    LDI R12, 0
D04_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D04_I
    ADDI R11, R11, -1
    BNE  R11, R0, D04_O

-- ============================================================
-- TEST 05: ADDI (positive)
-- ============================================================
TEST_05:
    LDI R15, 0x0500
    ST  R15, [0xFFFC]
    LDI R1, 100
    ADDI R2, R1, 55
    LDI R3, 155
    BEQ R2, R3, PASS_05
FAIL_05:
    LDI R15, 0x0502
    ST  R15, [0xFFFC]
    HALT
PASS_05:
    LDI R15, 0x0501
    ST  R15, [0xFFFC]
    LDI R11, 8
D05_O:
    LDI R12, 0
D05_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D05_I
    ADDI R11, R11, -1
    BNE  R11, R0, D05_O

-- ============================================================
-- TEST 06: ADDI (negative)
-- ============================================================
TEST_06:
    LDI R15, 0x0600
    ST  R15, [0xFFFC]
    LDI R1, 100
    ADDI R2, R1, -10
    LDI R3, 90
    BEQ R2, R3, PASS_06
FAIL_06:
    LDI R15, 0x0602
    ST  R15, [0xFFFC]
    HALT
PASS_06:
    LDI R15, 0x0601
    ST  R15, [0xFFFC]
    LDI R11, 8
D06_O:
    LDI R12, 0
D06_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D06_I
    ADDI R11, R11, -1
    BNE  R11, R0, D06_O

-- ============================================================
-- TEST 07: AND
-- ============================================================
TEST_07:
    LDI R15, 0x0700
    ST  R15, [0xFFFC]
    LDI R1, 0x00FF
    LDI R2, 0x000F
    AND R3, R1, R2
    LDI R4, 0x000F
    BEQ R3, R4, PASS_07
FAIL_07:
    LDI R15, 0x0702
    ST  R15, [0xFFFC]
    HALT
PASS_07:
    LDI R15, 0x0701
    ST  R15, [0xFFFC]
    LDI R11, 8
D07_O:
    LDI R12, 0
D07_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D07_I
    ADDI R11, R11, -1
    BNE  R11, R0, D07_O

-- ============================================================
-- TEST 08: OR
-- ============================================================
TEST_08:
    LDI R15, 0x0800
    ST  R15, [0xFFFC]
    LDI R1, 0x00F0
    LDI R2, 0x000F
    OR  R3, R1, R2
    LDI R4, 0x00FF
    BEQ R3, R4, PASS_08
FAIL_08:
    LDI R15, 0x0802
    ST  R15, [0xFFFC]
    HALT
PASS_08:
    LDI R15, 0x0801
    ST  R15, [0xFFFC]
    LDI R11, 8
D08_O:
    LDI R12, 0
D08_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D08_I
    ADDI R11, R11, -1
    BNE  R11, R0, D08_O

-- ============================================================
-- TEST 09: XOR
-- ============================================================
TEST_09:
    LDI R15, 0x0900
    ST  R15, [0xFFFC]
    LDI R1, 0x00FF
    LDI R2, 0x00AA
    XOR R3, R1, R2
    LDI R4, 0x0055
    BEQ R3, R4, PASS_09
FAIL_09:
    LDI R15, 0x0902
    ST  R15, [0xFFFC]
    HALT
PASS_09:
    LDI R15, 0x0901
    ST  R15, [0xFFFC]
    LDI R11, 8
D09_O:
    LDI R12, 0
D09_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D09_I
    ADDI R11, R11, -1
    BNE  R11, R0, D09_O

-- ============================================================
-- TEST 0A: ANDI
-- ============================================================
TEST_0A:
    LDI R15, 0x0A00
    ST  R15, [0xFFFC]
    LDI R1, 0xABCD
    ANDI R3, R1, 0x00FF
    LDI R4, 0x00CD
    BEQ R3, R4, PASS_0A
FAIL_0A:
    LDI R15, 0x0A02
    ST  R15, [0xFFFC]
    HALT
PASS_0A:
    LDI R15, 0x0A01
    ST  R15, [0xFFFC]
    LDI R11, 8
D0A_O:
    LDI R12, 0
D0A_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0A_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0A_O

-- ============================================================
-- TEST 0B: ORI
-- ============================================================
TEST_0B:
    LDI R15, 0x0B00
    ST  R15, [0xFFFC]
    LDI R1, 0x1200
    ORI R2, R1, 0x0034
    LDI R3, 0x1234
    BEQ R2, R3, PASS_0B
FAIL_0B:
    LDI R15, 0x0B02
    ST  R15, [0xFFFC]
    HALT
PASS_0B:
    LDI R15, 0x0B01
    ST  R15, [0xFFFC]
    LDI R11, 8
D0B_O:
    LDI R12, 0
D0B_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0B_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0B_O

-- ============================================================
-- TEST 0C: XORI
-- ============================================================
TEST_0C:
    LDI R15, 0x0C00
    ST  R15, [0xFFFC]
    LDI R1, 0x0F0F
    XORI R2, R1, 0x00FF
    LDI R3, 0x0FF0
    BEQ R2, R3, PASS_0C
FAIL_0C:
    LDI R15, 0x0C02
    ST  R15, [0xFFFC]
    HALT
PASS_0C:
    LDI R15, 0x0C01
    ST  R15, [0xFFFC]
    LDI R11, 8
D0C_O:
    LDI R12, 0
D0C_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0C_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0C_O

-- ============================================================
-- TEST 0D: SHL
-- ============================================================
TEST_0D:
    LDI R15, 0x0D00
    ST  R15, [0xFFFC]
    LDI R1, 1
    SHL R2, R1, 4
    LDI R3, 16
    BEQ R2, R3, PASS_0D
FAIL_0D:
    LDI R15, 0x0D02
    ST  R15, [0xFFFC]
    HALT
PASS_0D:
    LDI R15, 0x0D01
    ST  R15, [0xFFFC]
    LDI R11, 24
D0D_O:
    LDI R12, 0
D0D_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0D_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0D_O

-- ============================================================
-- TEST 0E: SHR
-- ============================================================
TEST_0E:
    LDI R15, 0x0E00
    ST  R15, [0xFFFC]
    LDI R1, 128
    SHR R2, R1, 3
    LDI R3, 16
    BEQ R2, R3, PASS_0E
FAIL_0E:
    LDI R15, 0x0E02
    ST  R15, [0xFFFC]
    HALT
PASS_0E:
    LDI R15, 0x0E01
    ST  R15, [0xFFFC]
    LDI R11, 24
D0E_O:
    LDI R12, 0
D0E_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0E_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0E_O

-- ============================================================
-- TEST 0F: SAR (arithmetic shift right)
-- ============================================================
TEST_0F:
    LDI R15, 0x0F00
    ST  R15, [0xFFFC]
    LDI R1, 0xFFF0      -- -16
    SAR R2, R1, 2       -- -4
    LDI R3, 0xFFFC
    BEQ R2, R3, PASS_0F
FAIL_0F:
    LDI R15, 0x0F02
    ST  R15, [0xFFFC]
    HALT
PASS_0F:
    LDI R15, 0x0F01
    ST  R15, [0xFFFC]
    LDI R11, 24
D0F_O:
    LDI R12, 0
D0F_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D0F_I
    ADDI R11, R11, -1
    BNE  R11, R0, D0F_O

-- ============================================================
-- TEST 10: R0 hardwired zero
-- ============================================================
TEST_10:
    LDI R15, 0x1000
    ST  R15, [0xFFFC]
    LDI R0, 0x00FF      -- should be ignored
    LDI R1, 0
    BEQ R0, R1, PASS_10
FAIL_10:
    LDI R15, 0x1002
    ST  R15, [0xFFFC]
    HALT
PASS_10:
    LDI R15, 0x1001
    ST  R15, [0xFFFC]
    LDI R11, 24
D10_O:
    LDI R12, 0
D10_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D10_I
    ADDI R11, R11, -1
    BNE  R11, R0, D10_O

-- ============================================================
-- TEST 11: ST/LD absolute memory (0x2000)
-- ============================================================
TEST_11:
    LDI R15, 0x1100
    ST  R15, [0xFFFC]
    LDI R1, 0x1234
    ST  R1, [0x2000]
    LDI R1, 0
    LD  R2, [0x2000]
    LDI R3, 0x1234
    BEQ R2, R3, PASS_11
FAIL_11:
    LDI R15, 0x1102
    ST  R15, [0xFFFC]
    HALT
PASS_11:
    LDI R15, 0x1101
    ST  R15, [0xFFFC]
    LDI R11, 24
D11_O:
    LDI R12, 0
D11_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D11_I
    ADDI R11, R11, -1
    BNE  R11, R0, D11_O

-- ============================================================
-- TEST 12: LDX/STX base+offset memory (0x2000 + 4)
-- ============================================================
TEST_12:
    LDI R15, 0x1200
    ST  R15, [0xFFFC]
    LDI R5, 0x2000
    LDI R1, 0xBEEF
    STX R1, [R5 + 4]
    LDI R1, 0
    LDX R2, [R5 + 4]
    LDI R3, 0xBEEF
    BEQ R2, R3, PASS_12
FAIL_12:
    LDI R15, 0x1202
    ST  R15, [0xFFFC]
    HALT
PASS_12:
    LDI R15, 0x1201
    ST  R15, [0xFFFC]
    LDI R11, 24
D12_O:
    LDI R12, 0
D12_I:
    ADDI R12, R12, 1
    BNE  R12, R0, D12_I
    ADDI R11, R11, -1
    BNE  R11, R0, D12_O

-- ============================================================
-- TEST 13: Branches (BEQ/BNE) + Jump (J)
-- ============================================================
TEST_13:
    LDI R15, 0x1300
    ST  R15, [0xFFFC]
    LDI R1, 1
    LDI R2, 2
    BNE R1, R2, T13_BNE_OK
    J   FAIL_13
T13_BNE_OK:
    J   T13_SKIP
    J   FAIL_13
T13_SKIP:
    LDI R3, 0xCAFE
    LDI R4, 0xCAFE
    BEQ R3, R4, PASS_13
FAIL_13:
    LDI R15, 0x1302
    ST  R15, [0xFFFC]
    HALT
PASS_13:
    LDI R15, 0x1301
    ST  R15, [0xFFFC]

-- ============================================================
-- ALL TESTS PASSED
-- ============================================================
ALL_PASS:
    LDI R15, 0xFF01
    ST  R15, [0xFFFC]
    J   ALL_PASS
