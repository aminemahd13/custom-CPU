-- ============================================================
-- CPU DIAGNOSTIC ROM SOURCE
-- Reconstructed from VHDL Hex Dump
-- ============================================================

-- ============================================================
-- TEST 01: LDI (Load Immediate)
-- ============================================================
TEST_01:
    LDI R15, 0x0001     ; Test 01
    ST  R15, [0xFFFE]   ; Display "001"
    LDI R1, 0x00AB      ; R1 = 0xAB
    LDI R2, 0x00AB      ; Expected
    BEQ R1, R2, PASS_01 ; Pass if equal
    
    -- FAIL 01
    LDI R15, 0x0201     ; FAIL code
    ST  R15, [0xFFFE]
    HALT
    
PASS_01:
    LDI R15, 0x0101     ; PASS code
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 02: MV (Register Move)
-- ============================================================
TEST_02:
    LDI R15, 0x0002
    ST  R15, [0xFFFE]
    LDI R1, 0x00CD
    MV  R3, R1          ; R3 = R1
    BEQ R3, R1, PASS_02
    
    -- FAIL 02
    LDI R15, 0x0202
    ST  R15, [0xFFFE]
    HALT

PASS_02:
    LDI R15, 0x0102
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 03: ADD (5 + 7 = 12)
-- ============================================================
TEST_03:
    LDI R15, 0x0003
    ST  R15, [0xFFFE]
    LDI R1, 5
    LDI R2, 7
    ADD R3, R1, R2      ; R3 = 12
    LDI R4, 12
    BEQ R3, R4, PASS_03
    
    -- FAIL 03
    LDI R15, 0x0203
    ST  R15, [0xFFFE]
    HALT

PASS_03:
    LDI R15, 0x0103
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 04: SUB (20 - 8 = 12)
-- ============================================================
TEST_04:
    LDI R15, 0x0004
    ST  R15, [0xFFFE]
    LDI R1, 20
    LDI R2, 8
    SUB R3, R1, R2      ; R3 = 12
    LDI R4, 12
    BEQ R3, R4, PASS_04
    
    -- FAIL 04
    LDI R15, 0x0204
    ST  R15, [0xFFFE]
    HALT

PASS_04:
    LDI R15, 0x0104
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 05: ADDI (100 + 55 = 155)
-- ============================================================
TEST_05:
    LDI R15, 0x0005
    ST  R15, [0xFFFE]
    LDI R1, 100
    ADDI R2, R1, 55     ; R2 = 155
    LDI R3, 155
    BEQ R2, R3, PASS_05
    
    -- FAIL 05
    LDI R15, 0x0205
    ST  R15, [0xFFFE]
    HALT

PASS_05:
    LDI R15, 0x0105
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 06: AND (0xFF & 0x0F = 0x0F)
-- ============================================================
TEST_06:
    LDI R15, 0x0006
    ST  R15, [0xFFFE]
    LDI R1, 0x00FF
    LDI R2, 0x0F
    AND R3, R1, R2
    LDI R4, 0x0F
    BEQ R3, R4, PASS_06
    
    -- FAIL 06
    LDI R15, 0x0206
    ST  R15, [0xFFFE]
    HALT

PASS_06:
    LDI R15, 0x0106
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 07: OR (0xF0 | 0x0F = 0xFF)
-- ============================================================
TEST_07:
    LDI R15, 0x0007
    ST  R15, [0xFFFE]
    LDI R1, 0xF0
    LDI R2, 0x0F
    OR  R3, R1, R2
    LDI R4, 0xFF
    BEQ R3, R4, PASS_07
    
    -- FAIL 07
    LDI R15, 0x0207
    ST  R15, [0xFFFE]
    HALT

PASS_07:
    LDI R15, 0x0107
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 08: XOR (0xFF ^ 0xAA = 0x55)
-- ============================================================
TEST_08:
    LDI R15, 0x0008
    ST  R15, [0xFFFE]
    LDI R1, 0xFF
    LDI R2, 0xAA
    XOR R3, R1, R2
    LDI R4, 0x55
    BEQ R3, R4, PASS_08
    
    -- FAIL 08
    LDI R15, 0x0208
    ST  R15, [0xFFFE]
    HALT

PASS_08:
    LDI R15, 0x0108
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 09: ANDI (0xABCD & 0x00FF = 0x00CD)
-- ============================================================
TEST_09:
    LDI R15, 0x0009
    ST  R15, [0xFFFE]
    LDI R1, 0xABCD
    ANDI R3, R1, 0x00FF
    LDI R4, 0x00CD
    BEQ R3, R4, PASS_09
    
    -- FAIL 09
    LDI R15, 0x0209
    ST  R15, [0xFFFE]
    HALT

PASS_09:
    LDI R15, 0x0109
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0A: SHL (1 << 4 = 16)
-- ============================================================
TEST_0A:
    LDI R15, 0x000A
    ST  R15, [0xFFFE]
    LDI R1, 1
    SHL R2, R1, 4
    LDI R3, 16
    BEQ R2, R3, PASS_0A
    
    -- FAIL 0A
    LDI R15, 0x020A
    ST  R15, [0xFFFE]
    HALT

PASS_0A:
    LDI R15, 0x010A
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0B: SHR (128 >> 3 = 16)
-- ============================================================
TEST_0B:
    LDI R15, 0x000B
    ST  R15, [0xFFFE]
    LDI R1, 128
    SHR R2, R1, 3
    LDI R3, 16
    BEQ R2, R3, PASS_0B
    
    -- FAIL 0B
    LDI R15, 0x020B
    ST  R15, [0xFFFE]
    HALT

PASS_0B:
    LDI R15, 0x010B
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0C: R0 Hardwired Zero
-- ============================================================
TEST_0C:
    LDI R15, 0x000C
    ST  R15, [0xFFFE]
    LDI R0, 0x00FF      ; Should be ignored
    LDI R1, 0
    BEQ R0, R1, PASS_0C ; R0 should still be 0
    
    -- FAIL 0C
    LDI R15, 0x020C
    ST  R15, [0xFFFE]
    HALT

PASS_0C:
    LDI R15, 0x010C
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0D: ST/LD Memory
-- ============================================================
TEST_0D:
    LDI R15, 0x000D
    ST  R15, [0xFFFE]
    LDI R1, 0x1234
    ST  R1, [0x2000]
    LDI R1, 0           ; Clear R1
    LD  R2, [0x2000]    ; Load back
    LDI R3, 0x1234
    BEQ R2, R3, PASS_0D
    
    -- FAIL 0D
    LDI R15, 0x020D
    ST  R15, [0xFFFE]
    HALT

PASS_0D:
    LDI R15, 0x010D
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0E: LDX/STX Base+Offset
-- ============================================================
TEST_0E:
    LDI R15, 0x000E
    ST  R15, [0xFFFE]
    LDI R5, 0x2000      ; Base
    LDI R1, 0xBEEF
    STX R1, [R5 + 4]    ; Store at 0x2004
    LDI R1, 0
    LDX R2, [R5 + 4]    ; Load from 0x2004
    LDI R3, 0xBEEF
    BEQ R2, R3, PASS_0E
    
    -- FAIL 0E
    LDI R15, 0x020E
    ST  R15, [0xFFFE]
    HALT

PASS_0E:
    LDI R15, 0x010E
    ST  R15, [0xFFFE]

-- ============================================================
-- TEST 0F: ADDI Negative
-- ============================================================
TEST_0F:
    LDI R15, 0x000F
    ST  R15, [0xFFFE]
    LDI R1, 100
    ADDI R2, R1, -10    ; 100 - 10 = 90
    LDI R3, 90
    BEQ R2, R3, PASS_0F
    
    -- FAIL 0F
    LDI R15, 0x020F
    ST  R15, [0xFFFE]
    HALT

PASS_0F:
    LDI R15, 0x010F
    ST  R15, [0xFFFE]

-- ============================================================
-- VICTORY LOOP
-- ============================================================
VICTORY:
    LDI R14, 8          ; Unused in this specific loop version, but kept
    LDI R1, 0x03FF      ; ON pattern
    LDI R2, 0x0000      ; OFF pattern

BLINK_LOOP:
    ST  R1, [0xFFFE]    ; Display ON
    
    -- Delay ON
    LDI R12, 0xFFF0     ; Short delay counter
DELAY_ON:
    ADDI R12, R12, 1
    BNE  R12, R0, DELAY_ON
    
    ST  R2, [0xFFFE]    ; Display OFF
    
    -- Delay OFF
    LDI R12, 0xFFF0     ; Short delay counter
DELAY_OFF:
    ADDI R12, R12, 1
    BNE  R12, R0, DELAY_OFF
    
    J BLINK_LOOP