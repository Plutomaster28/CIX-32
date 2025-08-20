// Enhanced ALU with Full x86 Operations for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_alu (
    input  alu_op_t      alu_op,
    input              ALU_ROR: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else begin
                    rot_amount = shift_amount % 32;
                    alu_res = (op_a >> rot_amount) | (op_a << (32 - rot_amount));
                    carry_out = alu_res[31];
                    if (shift_amount == 1) begin
                        overflow = alu_res[31] ^ op_a[30];
                    end
                end
            end  op_a,
    input  logic [31:0]  op_b,
    input  logic [4:0]   shift_amount,
    input  logic         carry_in,
    input  logic         is_8bit,
    input  logic         is_16bit,
    
    output logic [31:0]  result,
    output logic [63:0]  result_wide, // For multiply operations
    output logic         cf,
    output logic         zf,
    output logic         sf,
    output logic         of,
    output logic         pf,
    output logic         af,
    output logic         valid_result
);

    logic [31:0] alu_res;
    logic [63:0] wide_result;
    logic        carry_out;
    logic        overflow;
    logic        aux_carry;
    
    // Intermediate values for complex operations
    logic [32:0] add_result;
    logic [32:0] sub_result;
    logic [31:0] and_result;
    logic [31:0] or_result;
    logic [31:0] xor_result;
    logic [31:0] shift_result;
    logic [63:0] mul_result;
    
    // Shift/rotate logic
    logic [31:0] shifted_value;
    logic        shift_carry;
    logic [4:0]  rot_amount;  // Rotation amount for rotate operations
    
    always_comb begin
        // Initialize outputs
        alu_res = 32'd0;
        wide_result = 64'd0;
        carry_out = 1'b0;
        overflow = 1'b0;
        aux_carry = 1'b0;
        shift_carry = 1'b0;
        valid_result = 1'b1;
        
        // Main ALU operation
        case (alu_op)
            ALU_ADD: begin
                add_result = {1'b0, op_a} + {1'b0, op_b} + {32'b0, carry_in};
                alu_res = add_result[31:0];
                carry_out = add_result[32];
                
                // Overflow detection
                if (is_8bit) begin
                    overflow = (op_a[7] == op_b[7]) && (op_a[7] != alu_res[7]);
                    aux_carry = (op_a[3:0] + op_b[3:0] + carry_in) > 4'hF;
                end else if (is_16bit) begin
                    overflow = (op_a[15] == op_b[15]) && (op_a[15] != alu_res[15]);
                    aux_carry = (op_a[3:0] + op_b[3:0] + carry_in) > 4'hF;
                end else begin
                    overflow = (op_a[31] == op_b[31]) && (op_a[31] != alu_res[31]);
                    aux_carry = (op_a[3:0] + op_b[3:0] + carry_in) > 4'hF;
                end
            end
            
            ALU_SUB, ALU_CMP: begin
                sub_result = {1'b0, op_a} - {1'b0, op_b} - {32'b0, carry_in};
                alu_res = sub_result[31:0];
                carry_out = sub_result[32]; // Borrow
                
                // Overflow detection for subtraction
                if (is_8bit) begin
                    overflow = (op_a[7] != op_b[7]) && (op_a[7] != alu_res[7]);
                    aux_carry = (op_a[3:0] < (op_b[3:0] + carry_in));
                end else if (is_16bit) begin
                    overflow = (op_a[15] != op_b[15]) && (op_a[15] != alu_res[15]);
                    aux_carry = (op_a[3:0] < (op_b[3:0] + carry_in));
                end else begin
                    overflow = (op_a[31] != op_b[31]) && (op_a[31] != alu_res[31]);
                    aux_carry = (op_a[3:0] < (op_b[3:0] + carry_in));
                end
            end
            
            ALU_AND, ALU_TEST: begin
                and_result = op_a & op_b;
                alu_res = and_result;
                carry_out = 1'b0; // AND clears CF and OF
                overflow = 1'b0;
            end
            
            ALU_OR: begin
                or_result = op_a | op_b;
                alu_res = or_result;
                carry_out = 1'b0; // OR clears CF and OF
                overflow = 1'b0;
            end
            
            ALU_XOR: begin
                xor_result = op_a ^ op_b;
                alu_res = xor_result;
                carry_out = 1'b0; // XOR clears CF and OF
                overflow = 1'b0;
            end
            
            ALU_SHL: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else if (shift_amount <= 32) begin
                    {shift_carry, alu_res} = {op_a, 1'b0} << (shift_amount - 1);
                    carry_out = shift_carry;
                    if (shift_amount == 1) begin
                        overflow = alu_res[31] ^ carry_out;
                    end
                end else begin
                    alu_res = 32'h0;
                    carry_out = 1'b0;
                end
            end
            
            ALU_SHR: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else if (shift_amount <= 32) begin
                    {alu_res, shift_carry} = {1'b0, op_a} >> (shift_amount - 1);
                    carry_out = shift_carry;
                    if (shift_amount == 1) begin
                        overflow = op_a[31];
                    end
                end else begin
                    alu_res = 32'h0;
                    carry_out = 1'b0;
                end
            end
            
            ALU_SAR: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else if (shift_amount <= 32) begin
                    alu_res = $signed(op_a) >>> shift_amount;
                    carry_out = op_a[shift_amount - 1];
                    overflow = 1'b0; // SAR never sets OF
                end else begin
                    alu_res = op_a[31] ? 32'hFFFFFFFF : 32'h00000000;
                    carry_out = op_a[31];
                end
            end
            
            ALU_ROL: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else begin
                    rot_amount = shift_amount % 32;
                    alu_res = (op_a << rot_amount) | (op_a >> (32 - rot_amount));
                    carry_out = alu_res[0];
                    if (shift_amount == 1) begin
                        overflow = alu_res[31] ^ carry_out;
                    end
                end
            end
            
            ALU_ROR: begin
                if (shift_amount == 0) begin
                    alu_res = op_a;
                end else begin
                    rot_amount = shift_amount % 32;
                    alu_res = (op_a >> rot_amount) | (op_a << (32 - rot_amount));
                    carry_out = alu_res[31];
                    if (shift_amount == 1) begin
                        overflow = alu_res[31] ^ alu_res[30];
                    end
                end
            end
            
            ALU_INC: begin
                add_result = {1'b0, op_a} + 33'd1;
                alu_res = add_result[31:0];
                // INC doesn't affect CF in x86
                carry_out = carry_in; // Preserve existing CF
                
                if (is_8bit) begin
                    overflow = (op_a[7] == 1'b0) && (alu_res[7] == 1'b1);
                    aux_carry = (op_a[3:0] == 4'hF);
                end else if (is_16bit) begin
                    overflow = (op_a[15] == 1'b0) && (alu_res[15] == 1'b1);
                    aux_carry = (op_a[3:0] == 4'hF);
                end else begin
                    overflow = (op_a[31] == 1'b0) && (alu_res[31] == 1'b1);
                    aux_carry = (op_a[3:0] == 4'hF);
                end
            end
            
            ALU_DEC: begin
                sub_result = {1'b0, op_a} - 33'd1;
                alu_res = sub_result[31:0];
                // DEC doesn't affect CF in x86
                carry_out = carry_in; // Preserve existing CF
                
                if (is_8bit) begin
                    overflow = (op_a[7] == 1'b1) && (alu_res[7] == 1'b0);
                    aux_carry = (op_a[3:0] == 4'h0);
                end else if (is_16bit) begin
                    overflow = (op_a[15] == 1'b1) && (alu_res[15] == 1'b0);
                    aux_carry = (op_a[3:0] == 4'h0);
                end else begin
                    overflow = (op_a[31] == 1'b1) && (alu_res[31] == 1'b0);
                    aux_carry = (op_a[3:0] == 4'h0);
                end
            end
            
            ALU_PASS_A: begin
                alu_res = op_a;
            end
            
            ALU_PASS_B: begin
                alu_res = op_b;
            end
            
            default: begin
                alu_res = 32'd0;
                valid_result = 1'b0;
            end
        endcase
    end

    // Result masking based on operand size
    logic [31:0] masked_result;
    always_comb begin
        if (is_8bit) begin
            masked_result = {24'h0, alu_res[7:0]};
        end else if (is_16bit) begin
            masked_result = {16'h0, alu_res[15:0]};
        end else begin
            masked_result = alu_res;
        end
    end

    assign result = masked_result;
    assign result_wide = wide_result;

    // Flag generation
    assign cf = carry_out;
    assign of = overflow;
    assign af = aux_carry;

    // Zero flag - based on the appropriate result size
    assign zf = is_8bit  ? (alu_res[7:0] == 8'h0) :
                is_16bit ? (alu_res[15:0] == 16'h0) :
                          (alu_res == 32'h0);

    // Sign flag - MSB of result based on operand size
    assign sf = is_8bit  ? alu_res[7] :
                is_16bit ? alu_res[15] :
                          alu_res[31];

    // Parity flag - even parity of low 8 bits
    assign pf = ~^alu_res[7:0];

endmodule