import sys
import re

# ==========================================
# 1. Architecture Definition (Instruction Set)
# ==========================================
# [cite_start]Based on Spec: 3.2 Opcode Table [cite: 60]

OPCODES = {
    # Control
    'NOP':  0x00, 'HALT': 0xFF,
    
    # Constants
    'LDI':  0x01, 

    # Move
    'MV':   0x02,

    # ALU (2 Source Registers -> 1 Dest)
    'ADD':  0x10, 'SUB':  0x11, 
    'AND':  0x20, 'OR':   0x21, 'XOR':  0x22,

    # ALU (1 Source Register + Immediate)
    # Note: SHL/SHR/SAR are grouped here because they take an immediate shift amount
    'ADDI': 0x12, 
    'ANDI': 0x23, 'ORI':  0x24, 'XORI': 0x25,
    'SHL':  0x30, 'SHR':  0x31, 'SAR':  0x32,

    # Memory (Absolute Address)
    'LD':   0x40, 'ST':   0x41,

    # Memory (Base + Offset)
    'LDX':  0x42, 'STX':  0x43,

    # Branches
    'BEQ':  0x50, 'BNE':  0x51, 'J':    0x52
}

# Register Mapping R0-R15
REGISTERS = {f'R{i}': i for i in range(16)}

# ==========================================
# 2. Parsing & Helper Functions
# ==========================================

def clean_and_split(line):
    """
    Sanitizes input line to handle brackets and punctuation.
    Example: 'LDX R1, [R2+4]' -> ['LDX', 'R1', 'R2', '4']
    """
    # Remove comments (--) and whitespace
    line = line.split('--')[0].split(';')[0].strip()
    if not line:
        return []
    
    # Replace syntax chars with spaces to simplify splitting
    # Handles: commas, brackets [ ], and plus + (for R+Offset)
    line = line.replace('[', ' ').replace(']', ' ').replace('+', ' ').replace(',', ' ')
    
    return line.split()

def parse_reg(arg):
    arg = arg.upper().strip()
    if arg in REGISTERS:
        return REGISTERS[arg]
    raise ValueError(f"Unknown register: {arg}")

def parse_imm(arg):
    """Parses decimal or hex (0x...) immediate values, masking to 16-bit."""
    arg = arg.strip()
    try:
        if '0x' in arg.lower() or '0X' in arg:
            val = int(arg, 16)
        else:
            val = int(arg)
        return val & 0xFFFF
    except ValueError:
        raise ValueError(f"Invalid immediate value: {arg}")

def get_branch_offset(current_pc, label_target):
    """Calculates PC-relative offset: Target = PC + 1 + offset"""
    offset = label_target - current_pc - 1
    return offset & 0xFFFF

# ==========================================
# 3. Assembler Core
# ==========================================

def assemble(input_file):
    print(f"Assembling {input_file}...")
    
    # --- PASS 1: Symbol Table (Labels) ---
    labels = {}
    clean_lines = [] # Store (line_index, [tokens], original_comment)
    pc = 0
    
    try:
        with open(input_file, 'r') as f:
            raw_lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: File '{input_file}' not found.")
        return

    for line in raw_lines:
        tokens = clean_and_split(line)
        if not tokens: continue

        # Check for Label (ends with :)
        if tokens[0].endswith(':'):
            label_name = tokens[0][:-1]
            if label_name in labels:
                print(f"Error: Duplicate label '{label_name}'")
                return
            labels[label_name] = pc
            
            # If line was just a label, skip instruction generation
            if len(tokens) == 1:
                continue
            # Remove label from tokens for Pass 2
            tokens = tokens[1:]
        
        # Save for Pass 2
        clean_lines.append( (pc, tokens, line.strip()) )
        pc += 1

    # --- PASS 2: Code Generation ---
    vhdl_output = []
    
    for (pc, tokens, orig_line) in clean_lines:
        mnemonic = tokens[0].upper()
        args = tokens[1:]
        
        if mnemonic not in OPCODES:
            print(f"Error at PC={pc}: Unknown mnemonic '{mnemonic}'")
            return

        opcode = OPCODES[mnemonic]
        machine_code = 0
        
        try:
            # -------------------------------------------------
            # TYPE 1: No Operands (NOP, HALT)
            # -------------------------------------------------
            if mnemonic in ['NOP', 'HALT']:
                machine_code = (opcode << 24)

            # -------------------------------------------------
            # TYPE 2: Dest + Imm (LDI)
            # Format: LDI RD, IMM
            # -------------------------------------------------
            elif mnemonic == 'LDI':
                r_dest = parse_reg(args[0])
                imm = parse_imm(args[1])
                machine_code = (opcode << 24) | (r_dest << 20) | imm

            # -------------------------------------------------
            # TYPE 3: 3-Register Arithmetic (ADD, SUB, AND...)
            # Format: ADD RD, RA, RB
            # Special Case: MV RD, RA (RB=0)
            # -------------------------------------------------
            elif mnemonic in ['ADD', 'SUB', 'AND', 'OR', 'XOR', 'MV']:
                r_dest = parse_reg(args[0])
                r_srcA = parse_reg(args[1])
                r_srcB = 0
                
                if mnemonic != 'MV':
                    r_srcB = parse_reg(args[2]) # IMM16[3:0] holds RB
                
                # Spec: RA is bits 19:16, RB is bits 3:0
                machine_code = (opcode << 24) | (r_dest << 20) | (r_srcA << 16) | r_srcB

            # -------------------------------------------------
            # TYPE 4: Reg + Reg + Imm (ADDI, Shifts)
            # Format: ADDI RD, RA, IMM  or  SHL RD, RA, AMT
            # -------------------------------------------------
            elif mnemonic in ['ADDI', 'ANDI', 'ORI', 'XORI', 'SHL', 'SHR', 'SAR']:
                r_dest = parse_reg(args[0])
                r_srcA = parse_reg(args[1])
                imm = parse_imm(args[2])
                
                machine_code = (opcode << 24) | (r_dest << 20) | (r_srcA << 16) | imm

            # -------------------------------------------------
            # TYPE 5: Memory Absolute (LD, ST)
            # Format: LD RD, [IMM] -> Parsed as: LD RD IMM
            # -------------------------------------------------
            elif mnemonic in ['LD', 'ST']:
                r_dest = parse_reg(args[0]) # For ST, this is Source
                imm = parse_imm(args[1])
                
                machine_code = (opcode << 24) | (r_dest << 20) | imm

            # -------------------------------------------------
            # TYPE 6: Memory Indexed (LDX, STX)
            # Format: LDX RD, [RA + IMM] -> Parsed as: LDX RD RA IMM
            # -------------------------------------------------
            elif mnemonic in ['LDX', 'STX']:
                r_dest = parse_reg(args[0])
                r_base = parse_reg(args[1])
                imm = parse_imm(args[2])
                
                machine_code = (opcode << 24) | (r_dest << 20) | (r_base << 16) | imm

            # -------------------------------------------------
            # TYPE 7: Conditional Branch (BEQ, BNE)
            # Format: BEQ R1, R2, Label
            # Spec Encoding Example: BEQ R1, R2 -> 50 | 1(RD) | 2(RA)
            # -------------------------------------------------
            elif mnemonic in ['BEQ', 'BNE']:
                r_op1 = parse_reg(args[0]) # Mapped to RD (23:20)
                r_op2 = parse_reg(args[1]) # Mapped to RA (19:16)
                target = args[2]
                
                if target in labels:
                    imm = get_branch_offset(pc, labels[target])
                else:
                    imm = parse_imm(target)
                
                machine_code = (opcode << 24) | (r_op1 << 20) | (r_op2 << 16) | imm

            # -------------------------------------------------
            # TYPE 8: Unconditional Jump (J)
            # Format: J Label
            # -------------------------------------------------
            elif mnemonic == 'J':
                target = args[0]
                if target in labels:
                    imm = get_branch_offset(pc, labels[target])
                else:
                    imm = parse_imm(target)
                    
                machine_code = (opcode << 24) | imm

            # Output Formatting for VHDL
            hex_val = f'x"{machine_code:08X}"'
            vhdl_line = f'{pc:<3} => {hex_val}, -- {orig_line}'
            vhdl_output.append(vhdl_line)

        except Exception as e:
            print(f"Error on line: '{orig_line}'")
            print(f"Details: {e}")
            return

    # --- Print Result ---
    print("\n" + "="*50)
    print(" VHDL ROM CONTENT (Copy into instr_rom.vhd)")
    print("="*50)
    for line in vhdl_output:
        print(line)
    print("others => x\"00000000\"")
    print("="*50)


if __name__ == "__main__":
    assemble(sys.argv[1])