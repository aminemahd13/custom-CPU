library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity cpu_core is
    port (
        clk         : in  std_logic;
        rst         : in  std_logic;
        
        -- Instruction Interface
        pc_out      : out unsigned(15 downto 0);
        instr_in    : in  std_logic_vector(31 downto 0);
        
        -- Data Memory Interface
        mem_addr    : out unsigned(15 downto 0);
        mem_wdata   : out std_logic_vector(15 downto 0);
        mem_we      : out std_logic;
        mem_re      : out std_logic;
        mem_rdata   : in  std_logic_vector(15 downto 0)
    );
end entity cpu_core;

architecture rtl of cpu_core is
    -- FSM States
    type state_type is (
        S_RESET, S_FETCH, S_FETCH_WAIT, S_DECODE,
        S_EXEC_ALU, S_EXEC_BRANCH,
        S_MEM_ADDR, S_MEM_READ, S_MEM_READ_WAIT, S_MEM_WRITE,
        S_HALT
    );
    signal state : state_type := S_RESET;

    -- Registers
    type reg_file_type is array (0 to 15) of std_logic_vector(15 downto 0);
    signal regs : reg_file_type := (others => (others => '0'));
    
    signal pc        : unsigned(15 downto 0) := (others => '0');
    signal instr_reg : std_logic_vector(31 downto 0);
    
    -- Internal Decode Signals
    signal op_code   : std_logic_vector(7 downto 0);
    signal r_dest    : integer range 0 to 15;
    signal r_srcA    : integer range 0 to 15;
    signal r_srcB    : integer range 0 to 15;
    signal imm16     : std_logic_vector(15 downto 0);
    signal imm_s     : signed(15 downto 0); -- Sign extended
    signal imm_z     : unsigned(15 downto 0); -- Zero extended
    
    -- ALU/Effective Addr Buffers
    signal eff_addr  : unsigned(15 downto 0);
    signal alu_res   : std_logic_vector(15 downto 0);

begin
    -- Output PC continuously
    pc_out <= pc;

    -- Decode aliases
    op_code <= instr_reg(31 downto 24);
    r_dest  <= to_integer(unsigned(instr_reg(23 downto 20)));
    r_srcA  <= to_integer(unsigned(instr_reg(19 downto 16)));
    r_srcB  <= to_integer(unsigned(instr_reg(3 downto 0))); -- Encoded in low nibble of IMM for R-Type
    imm16   <= instr_reg(15 downto 0);
    imm_s   <= signed(imm16);
    imm_z   <= unsigned(imm16);

    process(clk)
        variable valA, valB : signed(15 downto 0);
        variable uValA : unsigned(15 downto 0);
        variable shamt : integer;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_RESET;
                pc    <= (others => '0');
                mem_we <= '0';
                mem_re <= '0';
            else
                -- Default strobes
                mem_we <= '0';
                mem_re <= '0';
                
                case state is
                    when S_RESET =>
                        pc <= (others => '0');
                        regs <= (others => (others => '0'));
                        state <= S_FETCH;

                    when S_FETCH =>
                        -- PC is already driving address port via pc_out
                        state <= S_FETCH_WAIT;

                    when S_FETCH_WAIT =>
                        -- Capture instruction from ROM
                        instr_reg <= instr_in;
                        state <= S_DECODE;

                    when S_DECODE =>
                        -- Decide path based on Opcode
                        if op_code = x"00" then -- NOP
                            pc <= pc + 1;
                            state <= S_FETCH;
                        elsif op_code(7 downto 4) = x"4" then -- Memory Ops (LD, ST)
                            state <= S_MEM_ADDR;
                        elsif op_code(7 downto 4) = x"5" then -- Branch Ops
                            state <= S_EXEC_BRANCH;
                        elsif op_code = x"FF" then -- HALT
                            state <= S_HALT;
                        else -- ALU Ops (0x01..0x3F)
                            state <= S_EXEC_ALU;
                        end if;

                    when S_EXEC_ALU =>
                        valA := signed(regs(r_srcA));
                        valB := signed(regs(r_srcB));
                        shamt := to_integer(unsigned(imm16(3 downto 0)));
                        
                        -- ALU Operation
                        case op_code is
                            when x"01" => alu_res <= imm16; -- LDI
                            when x"02" => alu_res <= regs(r_srcA); -- MV
                            when x"10" => alu_res <= std_logic_vector(valA + valB); -- ADD
                            when x"11" => alu_res <= std_logic_vector(valA - valB); -- SUB
                            when x"12" => alu_res <= std_logic_vector(valA + imm_s); -- ADDI
                            when x"20" => alu_res <= regs(r_srcA) and regs(r_srcB); -- AND
                            when x"21" => alu_res <= regs(r_srcA) or regs(r_srcB);  -- OR
                            when x"22" => alu_res <= regs(r_srcA) xor regs(r_srcB); -- XOR
                            when x"23" => alu_res <= regs(r_srcA) and imm16; -- ANDI
                            when x"24" => alu_res <= regs(r_srcA) or imm16;  -- ORI
                            when x"25" => alu_res <= regs(r_srcA) xor imm16; -- XORI
                            when x"30" => alu_res <= std_logic_vector(shift_left(unsigned(regs(r_srcA)), shamt)); -- SHL
                            when x"31" => alu_res <= std_logic_vector(shift_right(unsigned(regs(r_srcA)), shamt)); -- SHR
                            when x"32" => alu_res <= std_logic_vector(shift_right(signed(regs(r_srcA)), shamt)); -- SAR
                            when others => alu_res <= (others => '0');
                        end case;
                        
                        -- Writeback (R0 is constant zero)
                        if r_dest /= 0 then
                            regs(r_dest) <= alu_res; -- Note: This writes NEXT cycle, so fine.
                        end if;
                        
                        pc <= pc + 1;
                        state <= S_FETCH;

                    when S_EXEC_BRANCH =>
                        pc <= pc + 1; -- Default increment
                        
                        case op_code is
                            when x"50" => -- BEQ
                                if regs(r_srcA) = regs(r_dest) then
                                    pc <= pc + 1 + unsigned(imm_s);
                                end if;
                            when x"51" => -- BNE
                                if regs(r_srcA) /= regs(r_dest) then
                                    pc <= pc + 1 + unsigned(imm_s);
                                end if;
                            when x"52" => -- J
                                pc <= pc + 1 + unsigned(imm_s);
                            when others => null;
                        end case;
                        state <= S_FETCH;

                    when S_MEM_ADDR =>
                        -- Calculate Effective Address
                        case op_code is
                            when x"40" | x"41" => -- LD, ST (Absolute)
                                eff_addr <= imm_z;
                            when x"42" | x"43" => -- LDX, STX (Base + Offset)
                                eff_addr <= unsigned(signed(regs(r_srcA)) + imm_s);
                            when others => eff_addr <= (others => '0');
                        end case;

                        if op_code(0) = '0' then -- Even opcodes are Loads (40, 42)
                            state <= S_MEM_READ;
                        else -- Odd opcodes are Stores (41, 43)
                            state <= S_MEM_WRITE;
                        end if;

                    when S_MEM_READ =>
                        mem_addr <= eff_addr;
                        mem_re   <= '1';
                        state    <= S_MEM_READ_WAIT;

                    when S_MEM_READ_WAIT =>
                        if r_dest /= 0 then
                            regs(r_dest) <= mem_rdata;
                        end if;
                        pc <= pc + 1;
                        state <= S_FETCH;

                    when S_MEM_WRITE =>
                        mem_addr  <= eff_addr;
                        mem_wdata <= regs(r_dest); -- Store value comes from RD
                        mem_we    <= '1';
                        pc <= pc + 1;
                        state <= S_FETCH;

                    when S_HALT =>
                        state <= S_HALT; -- Spin forever
                        
                    when others =>
                        state <= S_RESET;
                end case;
            end if;
        end if;
    end process;

end architecture;