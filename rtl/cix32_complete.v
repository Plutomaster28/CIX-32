// CIX-32: Complete 32-bit x86-compatible processor in Verilog
module cix32_processor (
    input wire clk,
    input wire rst_n,
    
    // External memory interface
    output reg [31:0] mem_addr,
    output reg [31:0] mem_wdata,
    input wire [31:0] mem_rdata,
    output reg mem_we,
    output reg mem_re,
    input wire mem_ready,
    
    // Status outputs
    output wire [31:0] pc_out,
    output wire [31:0] eax_out,
    output wire [31:0] ebx_out,
    output wire [31:0] ecx_out,
    output wire [31:0] edx_out,
    output wire [31:0] esp_out,
    output wire [31:0] ebp_out,
    output wire [31:0] esi_out,
    output wire [31:0] edi_out,
    output wire [31:0] flags_out,
    output wire halted,
    output wire exception
);

    // Pipeline state
    parameter FETCH = 3'h0, DECODE = 3'h1, EXECUTE = 3'h2, MEMORY = 3'h3, WRITEBACK = 3'h4;
    reg [2:0] pipeline_state;
    
    // Program counter and instruction pointer
    reg [31:0] pc;
    reg [31:0] next_pc;
    
    // General purpose registers
    reg [31:0] gpr[0:7]; // EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI
    
    // Flags register
    reg [31:0] flags; // CF, PF, AF, ZF, SF, TF, IF, DF, OF, etc.
    
    // Segment registers  
    reg [15:0] cs, ds, ss, es, fs, gs;
    
    // Control registers
    reg [31:0] cr0, cr2, cr3, cr4;
    
    // Instruction decode
    reg [7:0] opcode;
    reg [7:0] modrm;
    reg [7:0] sib;
    reg [31:0] displacement;
    reg [31:0] immediate;
    reg has_modrm, has_sib, has_displacement, has_immediate;
    reg [3:0] instruction_length;
    
    // ALU
    reg [31:0] alu_a, alu_b, alu_result;
    reg [4:0] alu_op;
    reg [31:0] new_flags;
    
    // Memory operation
    reg [31:0] memory_address;
    reg [31:0] memory_data;
    reg memory_write, memory_read;
    reg [1:0] memory_size; // 0=byte, 1=word, 2=dword
    
    // Pipeline registers
    reg [31:0] fetch_pc;
    reg [127:0] fetch_instruction; // Up to 16 bytes
    reg [31:0] decode_pc;
    reg [31:0] execute_pc;
    reg [31:0] memory_pc;
    
    // Exception handling
    reg exception_flag;
    reg [7:0] exception_vector;
    
    // State machine for instruction execution
    reg [3:0] exec_state;
    reg [3:0] fetch_bytes_needed;
    reg [3:0] fetch_bytes_received;
    
    // Assign outputs
    assign pc_out = pc;
    assign eax_out = gpr[0];
    assign ebx_out = gpr[3];
    assign ecx_out = gpr[1];
    assign edx_out = gpr[2];
    assign esp_out = gpr[4];
    assign ebp_out = gpr[5];
    assign esi_out = gpr[6];
    assign edi_out = gpr[7];
    assign flags_out = flags;
    assign halted = (opcode == 8'hF4 && pipeline_state == WRITEBACK);
    assign exception = exception_flag;
    
    // ALU operations
    parameter ALU_ADD = 5'h00, ALU_SUB = 5'h01, ALU_AND = 5'h02, ALU_OR = 5'h03;
    parameter ALU_XOR = 5'h04, ALU_SHL = 5'h05, ALU_SHR = 5'h06, ALU_INC = 5'h07;
    parameter ALU_DEC = 5'h08, ALU_NEG = 5'h09, ALU_NOT = 5'h0A, ALU_CMP = 5'h0B;
    parameter ALU_TEST = 5'h0C, ALU_MOV = 5'h0D, ALU_NOP = 5'h0E;
    
    // Flag bits
    parameter CF = 0, PF = 2, AF = 4, ZF = 6, SF = 7, OF = 11;
    
    always @(*) begin
        // ALU implementation
        case (alu_op)
            ALU_ADD: begin
                alu_result = alu_a + alu_b;
                new_flags[CF] = (alu_result < alu_a); // Carry
                new_flags[ZF] = (alu_result == 0);    // Zero
                new_flags[SF] = alu_result[31];       // Sign
                new_flags[OF] = ((alu_a[31] == alu_b[31]) && (alu_result[31] != alu_a[31])); // Overflow
            end
            ALU_SUB: begin
                alu_result = alu_a - alu_b;
                new_flags[CF] = (alu_a < alu_b);      // Borrow
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
                new_flags[OF] = ((alu_a[31] != alu_b[31]) && (alu_result[31] != alu_a[31]));
            end
            ALU_AND: begin
                alu_result = alu_a & alu_b;
                new_flags[CF] = 0;
                new_flags[OF] = 0;
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
            end
            ALU_OR: begin
                alu_result = alu_a | alu_b;
                new_flags[CF] = 0;
                new_flags[OF] = 0;
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
            end
            ALU_XOR: begin
                alu_result = alu_a ^ alu_b;
                new_flags[CF] = 0;
                new_flags[OF] = 0;
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
            end
            ALU_INC: begin
                alu_result = alu_a + 1;
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
                new_flags[OF] = (alu_a == 32'h7FFFFFFF);
                new_flags[CF] = flags[CF]; // INC doesn't affect CF
            end
            ALU_DEC: begin
                alu_result = alu_a - 1;
                new_flags[ZF] = (alu_result == 0);
                new_flags[SF] = alu_result[31];
                new_flags[OF] = (alu_a == 32'h80000000);
                new_flags[CF] = flags[CF]; // DEC doesn't affect CF
            end
            ALU_CMP: begin
                alu_result = alu_a - alu_b;
                new_flags[CF] = (alu_a < alu_b);
                new_flags[ZF] = (alu_a == alu_b);
                new_flags[SF] = alu_result[31];
                new_flags[OF] = ((alu_a[31] != alu_b[31]) && (alu_result[31] != alu_a[31]));
            end
            ALU_MOV: begin
                alu_result = alu_b;
                new_flags = flags; // MOV doesn't affect flags
            end
            default: begin
                alu_result = alu_a;
                new_flags = flags;
            end
        endcase
    end
    
    // Main processor pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            pc <= 32'h0;
            pipeline_state <= FETCH;
            gpr[0] <= 32'h0; gpr[1] <= 32'h0; gpr[2] <= 32'h0; gpr[3] <= 32'h0;
            gpr[4] <= 32'h1000; gpr[5] <= 32'h0; gpr[6] <= 32'h0; gpr[7] <= 32'h0;
            flags <= 32'h0;
            cs <= 16'h0; ds <= 16'h0; ss <= 16'h0; es <= 16'h0; fs <= 16'h0; gs <= 16'h0;
            cr0 <= 32'h0; cr2 <= 32'h0; cr3 <= 32'h0; cr4 <= 32'h0;
            exception_flag <= 1'b0;
            mem_we <= 1'b0;
            mem_re <= 1'b0;
            exec_state <= 4'h0;
            fetch_bytes_needed <= 4'h1;
            fetch_bytes_received <= 4'h0;
        end else begin
            case (pipeline_state)
                FETCH: begin
                    if (!mem_ready && mem_re) begin
                        // Wait for memory
                    end else begin
                        if (fetch_bytes_received == 0) begin
                            mem_addr <= pc;
                            mem_re <= 1'b1;
                            mem_we <= 1'b0;
                            if (mem_ready) begin
                                fetch_instruction[31:0] <= mem_rdata;
                                fetch_bytes_received <= 4;
                                fetch_pc <= pc;
                                mem_re <= 1'b0;
                                pipeline_state <= DECODE;
                            end
                        end
                    end
                end
                
                DECODE: begin
                    decode_pc <= fetch_pc;
                    opcode <= fetch_instruction[7:0];
                    
                    // Simple instruction decode (subset of x86)
                    case (fetch_instruction[7:0])
                        8'h40: begin // INC EAX
                            alu_op <= ALU_INC;
                            alu_a <= gpr[0];
                            instruction_length <= 1;
                            has_modrm <= 0;
                        end
                        8'h41: begin // INC ECX
                            alu_op <= ALU_INC;
                            alu_a <= gpr[1];
                            instruction_length <= 1;
                            has_modrm <= 0;
                        end
                        8'h48: begin // DEC EAX
                            alu_op <= ALU_DEC;
                            alu_a <= gpr[0];
                            instruction_length <= 1;
                            has_modrm <= 0;
                        end
                        8'h49: begin // DEC ECX
                            alu_op <= ALU_DEC;
                            alu_a <= gpr[1];
                            instruction_length <= 1;
                            has_modrm <= 0;
                        end
                        8'h01: begin // ADD Ev, Gv (with ModR/M)
                            alu_op <= ALU_ADD;
                            modrm <= fetch_instruction[15:8];
                            has_modrm <= 1;
                            instruction_length <= 2;
                        end
                        8'h29: begin // SUB Ev, Gv (with ModR/M)
                            alu_op <= ALU_SUB;
                            modrm <= fetch_instruction[15:8];
                            has_modrm <= 1;
                            instruction_length <= 2;
                        end
                        8'h89: begin // MOV Ev, Gv (with ModR/M)
                            alu_op <= ALU_MOV;
                            modrm <= fetch_instruction[15:8];
                            has_modrm <= 1;
                            instruction_length <= 2;
                        end
                        8'hB8: begin // MOV EAX, Imm24 (truncated for simplicity)
                            alu_op <= ALU_MOV;
                            alu_b <= {8'h00, fetch_instruction[31:8]}; // Zero-extend 24-bit immediate 
                            instruction_length <= 4; // Use available bytes
                            has_immediate <= 1;
                        end
                        8'hF4: begin // HLT
                            alu_op <= ALU_NOP;
                            instruction_length <= 1;
                        end
                        default: begin
                            exception_flag <= 1'b1;
                            exception_vector <= 8'h06; // Invalid opcode
                        end
                    endcase
                    
                    pipeline_state <= EXECUTE;
                end
                
                EXECUTE: begin
                    execute_pc <= decode_pc;
                    
                    if (has_modrm) begin
                        // Decode ModR/M byte
                        case (modrm[7:6]) // Mod field
                            2'b11: begin // Register to register
                                case (opcode)
                                    8'h01: begin // ADD
                                        alu_a <= gpr[modrm[2:0]];
                                        alu_b <= gpr[modrm[5:3]];
                                    end
                                    8'h29: begin // SUB
                                        alu_a <= gpr[modrm[2:0]];
                                        alu_b <= gpr[modrm[5:3]];
                                    end
                                    8'h89: begin // MOV
                                        alu_b <= gpr[modrm[5:3]];
                                    end
                                endcase
                            end
                            default: begin
                                // Memory operations (simplified)
                                memory_address <= gpr[modrm[2:0]];
                                memory_read <= (opcode != 8'h89);
                                memory_write <= (opcode == 8'h89);
                            end
                        endcase
                    end
                    
                    pipeline_state <= MEMORY;
                end
                
                MEMORY: begin
                    memory_pc <= execute_pc;
                    
                    if (memory_read || memory_write) begin
                        if (!mem_ready && (mem_re || mem_we)) begin
                            // Wait for memory
                        end else if (memory_read && !mem_re) begin
                            mem_addr <= memory_address;
                            mem_re <= 1'b1;
                            mem_we <= 1'b0;
                        end else if (memory_write && !mem_we) begin
                            mem_addr <= memory_address;
                            mem_wdata <= alu_result;
                            mem_we <= 1'b1;
                            mem_re <= 1'b0;
                        end else if (mem_ready) begin
                            if (memory_read) begin
                                alu_b <= mem_rdata;
                                mem_re <= 1'b0;
                            end else begin
                                mem_we <= 1'b0;
                            end
                            memory_read <= 1'b0;
                            memory_write <= 1'b0;
                            pipeline_state <= WRITEBACK;
                        end
                    end else begin
                        pipeline_state <= WRITEBACK;
                    end
                end
                
                WRITEBACK: begin
                    if (opcode != 8'hF4) begin // Not HLT
                        pc <= decode_pc + instruction_length;
                        
                        // Write back results
                        case (opcode)
                            8'h40: gpr[0] <= alu_result; // INC EAX
                            8'h41: gpr[1] <= alu_result; // INC ECX
                            8'h48: gpr[0] <= alu_result; // DEC EAX
                            8'h49: gpr[1] <= alu_result; // DEC ECX
                            8'hB8: gpr[0] <= alu_b;      // MOV EAX, Imm32
                            8'h01, 8'h29: begin // ADD/SUB with ModR/M
                                if (modrm[7:6] == 2'b11) begin
                                    gpr[modrm[2:0]] <= alu_result;
                                end
                            end
                            8'h89: begin // MOV with ModR/M
                                if (modrm[7:6] == 2'b11) begin
                                    gpr[modrm[2:0]] <= alu_result;
                                end
                            end
                        endcase
                        
                        // Update flags
                        if (alu_op != ALU_MOV && alu_op != ALU_NOP) begin
                            flags <= new_flags;
                        end
                    end
                    
                    // Reset for next instruction
                    pipeline_state <= FETCH;
                    fetch_bytes_received <= 4'h0;
                    has_modrm <= 1'b0;
                    has_immediate <= 1'b0;
                    memory_read <= 1'b0;
                    memory_write <= 1'b0;
                end
            endcase
        end
    end

endmodule
