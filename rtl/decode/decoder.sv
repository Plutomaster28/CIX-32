// Enhanced x86 Instruction Decoder for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_decoder (
    input  logic         clk,
    input  logic         rst_n,

    // Raw bytes input stream (up to 16 bytes per x86 instruction max)
    input  logic [127:0] bytes_in,
    input  logic  [3:0]  valid_bytes, // how many bytes valid this cycle
    input  logic         in_valid,
    output logic         in_ready,

    // Decoded instruction output
    output decoded_inst_t decoded_inst,
    output logic         inst_valid,
    input  logic         inst_ready,

    // CPU mode for decode context
    input  cpu_mode_t    cpu_mode,
    
    // Current CS for relative jumps
    input  logic [15:0]  cs_reg
);

    // Instruction decode state machine
    typedef enum logic [2:0] {
        DECODE_PREFIX,
        DECODE_OPCODE,
        DECODE_MODRM,
        DECODE_SIB,
        DECODE_DISP,
        DECODE_IMM,
        DECODE_COMPLETE
    } decode_state_t;

    decode_state_t decode_state, next_decode_state;
    logic [7:0] instruction_bytes[0:15];
    logic [3:0] inst_length;
    logic [3:0] byte_index;
    
    prefix_t current_prefix;
    logic [7:0] opcode;
    logic [7:0] modrm_byte;
    logic [7:0] sib_byte;
    logic has_modrm, has_sib;
    logic [3:0] disp_size, imm_size;
    logic [31:0] displacement, immediate;

    // Basic handshake
    assign in_ready = inst_ready && (decode_state == DECODE_PREFIX); // Ready for new instruction

    // Load instruction bytes
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 16; i++) begin
                instruction_bytes[i] <= 8'h00;
            end
            byte_index <= 4'h0;
            inst_length <= 4'h0;
        end else if (in_valid && in_ready) begin
            // Load new instruction bytes
            for (i = 0; i < 16; i++) begin
                if (i < valid_bytes) begin
                    instruction_bytes[i] <= bytes_in[i*8 +: 8];
                end else begin
                    instruction_bytes[i] <= 8'h00;
                end
            end
            byte_index <= 4'h0;
            inst_length <= valid_bytes;
        end
    end

    // Decode state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            decode_state <= DECODE_PREFIX;
        end else begin
            decode_state <= next_decode_state;
        end
    end

    // Decode logic
    always_comb begin
        next_decode_state = decode_state;
        
        case (decode_state)
            DECODE_PREFIX: begin
                if (in_valid && in_ready) begin
                    next_decode_state = DECODE_OPCODE;
                end
            end
            
            DECODE_OPCODE: begin
                next_decode_state = has_modrm ? DECODE_MODRM : DECODE_DISP;
            end
            
            DECODE_MODRM: begin
                next_decode_state = has_sib ? DECODE_SIB : DECODE_DISP;
            end
            
            DECODE_SIB: begin
                next_decode_state = DECODE_DISP;
            end
            
            DECODE_DISP: begin
                next_decode_state = (imm_size > 0) ? DECODE_IMM : DECODE_COMPLETE;
            end
            
            DECODE_IMM: begin
                next_decode_state = DECODE_COMPLETE;
            end
            
            DECODE_COMPLETE: begin
                if (inst_ready) begin
                    next_decode_state = DECODE_PREFIX;
                end
            end
        endcase
    end

    // Prefix parsing
    always_comb begin
        current_prefix = '0;
        
        // Parse prefixes (simplified - only handle a few key ones)
        case (instruction_bytes[0])
            8'h26: current_prefix.seg_override = SEG_ES;
            8'h2E: current_prefix.seg_override = SEG_CS;
            8'h36: current_prefix.seg_override = SEG_SS;
            8'h3E: current_prefix.seg_override = SEG_DS;
            8'h64: current_prefix.seg_override = SEG_FS;
            8'h65: current_prefix.seg_override = SEG_GS;
            8'h66: current_prefix.operand_size = 1'b1;
            8'h67: current_prefix.address_size = 1'b1;
            8'hF0: current_prefix.lock = 1'b1;
            8'hF2: current_prefix.repnz = 1'b1;
            8'hF3: current_prefix.rep = 1'b1;
            default: ; // No prefix
        endcase
    end

    // Opcode parsing and instruction decode
    logic [3:0] prefix_length;
    always_comb begin
        prefix_length = 4'h0; // Simplified: assume no prefixes for now
        opcode = instruction_bytes[prefix_length];
        
        // Determine if ModR/M byte is needed
        has_modrm = 1'b0;
        has_sib = 1'b0;
        disp_size = 4'h0;
        imm_size = 4'h0;
        
        case (opcode)
            8'h88, 8'h89, 8'h8A, 8'h8B: has_modrm = 1'b1; // MOV r/m, r
            8'hC6, 8'hC7: begin has_modrm = 1'b1; imm_size = current_prefix.operand_size ? 4'h2 : 4'h4; end // MOV r/m, imm
            8'h01, 8'h03, 8'h05: has_modrm = 1'b1; // ADD variants
            8'h29, 8'h2B, 8'h2D: has_modrm = 1'b1; // SUB variants
            8'h21, 8'h23, 8'h25: has_modrm = 1'b1; // AND variants
            8'h09, 8'h0B, 8'h0D: has_modrm = 1'b1; // OR variants
            8'h31, 8'h33, 8'h35: has_modrm = 1'b1; // XOR variants
            8'h39, 8'h3B, 8'h3D: has_modrm = 1'b1; // CMP variants
            8'h85: has_modrm = 1'b1; // TEST r/m, r
            8'hFF: has_modrm = 1'b1; // Multiple operations (PUSH/POP/CALL/JMP r/m)
            8'h50, 8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57: ; // PUSH r
            8'h58, 8'h59, 8'h5A, 8'h5B, 8'h5C, 8'h5D, 8'h5E, 8'h5F: ; // POP r
            8'hE8: imm_size = 4'h4; // CALL rel32
            8'hE9: imm_size = 4'h4; // JMP rel32
            8'h70, 8'h71, 8'h72, 8'h73, 8'h74, 8'h75, 8'h76, 8'h77,
            8'h78, 8'h79, 8'h7A, 8'h7B, 8'h7C, 8'h7D, 8'h7E, 8'h7F: imm_size = 4'h1; // Jcc rel8
            default: ; // Single byte instructions
        endcase
        
        if (has_modrm) begin
            modrm_byte = instruction_bytes[prefix_length + 1];
            // Check if SIB byte is needed (Mod != 11 and R/M = 100 in 32-bit mode)
            if (modrm_byte[7:6] != 2'b11 && modrm_byte[2:0] == 3'b100 && !current_prefix.address_size) begin
                has_sib = 1'b1;
                sib_byte = instruction_bytes[prefix_length + 2];
            end
            
            // Determine displacement size based on ModR/M
            case (modrm_byte[7:6])
                2'b00: disp_size = (modrm_byte[2:0] == 3'b101) ? 4'h4 : 4'h0;
                2'b01: disp_size = 4'h1;
                2'b10: disp_size = 4'h4;
                2'b11: disp_size = 4'h0;
            endcase
        end
    end

    // Extract displacement and immediate values
    logic [3:0] disp_offset, imm_offset;
    always_comb begin
        disp_offset = prefix_length + (has_modrm ? 4'h1 : 4'h0) + (has_sib ? 4'h1 : 4'h0);
        imm_offset = disp_offset + disp_size;
        
        displacement = 32'h00000000;
        immediate = 32'h00000000;
        
        // Extract displacement
        case (disp_size)
            4'h1: displacement = {{24{instruction_bytes[disp_offset][7]}}, instruction_bytes[disp_offset]};
            4'h2: displacement = {{16{instruction_bytes[disp_offset+1][7]}}, instruction_bytes[disp_offset+1], instruction_bytes[disp_offset]};
            4'h4: displacement = {instruction_bytes[disp_offset+3], instruction_bytes[disp_offset+2], 
                                 instruction_bytes[disp_offset+1], instruction_bytes[disp_offset]};
        endcase
        
        // Extract immediate
        case (imm_size)
            4'h1: immediate = {{24{instruction_bytes[imm_offset][7]}}, instruction_bytes[imm_offset]};
            4'h2: immediate = {{16{instruction_bytes[imm_offset+1][7]}}, instruction_bytes[imm_offset+1], instruction_bytes[imm_offset]};
            4'h4: immediate = {instruction_bytes[imm_offset+3], instruction_bytes[imm_offset+2], 
                              instruction_bytes[imm_offset+1], instruction_bytes[imm_offset]};
        endcase
    end

    // Generate decoded instruction
    always_comb begin
        decoded_inst = '0;
        inst_valid = (decode_state == DECODE_COMPLETE);
        
        decoded_inst.prefix = current_prefix;
        decoded_inst.length = prefix_length + 4'h1 + (has_modrm ? 4'h1 : 4'h0) + 
                             (has_sib ? 4'h1 : 4'h0) + disp_size + imm_size;
        decoded_inst.has_modrm = has_modrm;
        decoded_inst.has_sib = has_sib;
        decoded_inst.displacement = displacement;
        decoded_inst.immediate = immediate;
        
        if (has_modrm) begin
            decoded_inst.dst_reg = modrm_byte[5:3];
            decoded_inst.src_reg = modrm_byte[2:0];
            if (has_sib) begin
                decoded_inst.base_reg = sib_byte[2:0];
                decoded_inst.index_reg = sib_byte[5:3];
                decoded_inst.scale = sib_byte[7:6];
            end else begin
                decoded_inst.base_reg = modrm_byte[2:0];
            end
        end
        
        // Decode specific instructions
        case (opcode)
            8'h90: decoded_inst.uop = UOP_NOP;
            8'hF4: decoded_inst.uop = UOP_HLT;
            8'h40, 8'h41, 8'h42, 8'h43, 8'h44, 8'h45, 8'h46, 8'h47: begin
                decoded_inst.uop = UOP_INC;
                decoded_inst.dst_reg = opcode[2:0];
                decoded_inst.reg_dst = 1'b1;
            end
            8'h48, 8'h49, 8'h4A, 8'h4B, 8'h4C, 8'h4D, 8'h4E, 8'h4F: begin
                decoded_inst.uop = UOP_DEC;
                decoded_inst.dst_reg = opcode[2:0];
                decoded_inst.reg_dst = 1'b1;
            end
            8'h88: begin // MOV r/m8, r8
                decoded_inst.uop = UOP_MOV_MR;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_src = 1'b1;
            end
            8'h89: begin // MOV r/m16/32, r16/32
                decoded_inst.uop = UOP_MOV_MR;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_src = 1'b1;
            end
            8'h8A: begin // MOV r8, r/m8
                decoded_inst.uop = UOP_MOV_RM;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_dst = 1'b1;
            end
            8'h8B: begin // MOV r16/32, r/m16/32
                decoded_inst.uop = UOP_MOV_RM;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_dst = 1'b1;
            end
            8'hC6, 8'hC7: begin // MOV r/m, imm
                decoded_inst.uop = UOP_MOV_RI;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.imm_op = 1'b1;
            end
            8'h01, 8'h03: begin // ADD variants
                decoded_inst.uop = UOP_ADD;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_src = 1'b1;
                decoded_inst.reg_dst = (opcode == 8'h03);
            end
            8'h29, 8'h2B: begin // SUB variants
                decoded_inst.uop = UOP_SUB;
                decoded_inst.mem_op = (modrm_byte[7:6] != 2'b11);
                decoded_inst.reg_src = 1'b1;
                decoded_inst.reg_dst = (opcode == 8'h2B);
            end
            8'h50, 8'h51, 8'h52, 8'h53, 8'h54, 8'h55, 8'h56, 8'h57: begin // PUSH r
                decoded_inst.uop = UOP_PUSH;
                decoded_inst.dst_reg = opcode[2:0];
                decoded_inst.reg_src = 1'b1;
            end
            8'h58, 8'h59, 8'h5A, 8'h5B, 8'h5C, 8'h5D, 8'h5E, 8'h5F: begin // POP r
                decoded_inst.uop = UOP_POP;
                decoded_inst.dst_reg = opcode[2:0];
                decoded_inst.reg_dst = 1'b1;
            end
            8'hE8: begin // CALL rel32
                decoded_inst.uop = UOP_CALL;
                decoded_inst.imm_op = 1'b1;
            end
            8'hC3: decoded_inst.uop = UOP_RET;
            8'hE9: begin // JMP rel32
                decoded_inst.uop = UOP_JMP;
                decoded_inst.imm_op = 1'b1;
            end
            8'h70, 8'h71, 8'h72, 8'h73, 8'h74, 8'h75, 8'h76, 8'h77,
            8'h78, 8'h79, 8'h7A, 8'h7B, 8'h7C, 8'h7D, 8'h7E, 8'h7F: begin // Jcc rel8
                decoded_inst.uop = UOP_JCC;
                decoded_inst.imm_op = 1'b1;
                decoded_inst.src_reg = opcode[2:0]; // Condition code
            end
            default: decoded_inst.uop = UOP_INVALID;
        endcase
    end

endmodule
