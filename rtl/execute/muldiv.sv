// Multiply/Divide Unit for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_muldiv (
    input  logic         clk,
    input  logic         rst_n,
    
    // Control interface
    input  logic         start,
    input  logic         is_signed,
    input  logic         is_div,     // 1 for divide, 0 for multiply
    input  logic         is_8bit,
    input  logic         is_16bit,
    
    // Data inputs
    input  logic [31:0]  op_a,
    input  logic [31:0]  op_b,
    input  logic [31:0]  op_high,   // For 64-bit dividend in division
    
    // Results
    output logic [63:0]  result,    // Product or quotient in low, remainder in high for division
    output logic         ready,
    output logic         divide_error,
    
    // Flags (for IMUL only)
    output logic         cf,
    output logic         of
);

    // State machine for multi-cycle operations
    typedef enum logic [2:0] {
        IDLE,
        MUL_CALC,
        DIV_CALC,
        COMPLETE
    } muldiv_state_t;
    
    muldiv_state_t state, next_state;
    logic [5:0] cycle_count;
    logic [63:0] working_result;
    logic [63:0] dividend;
    logic [31:0] divisor;
    logic [63:0] quotient;
    logic [31:0] remainder;
    
    // Booth multiplier state (simplified)
    logic [64:0] multiplier_state;
    logic [32:0] multiplicand;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 6'd0;
            working_result <= 64'd0;
            divide_error <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    cycle_count <= 6'd0;
                    divide_error <= 1'b0;
                    if (start) begin
                        if (is_div) begin
                            // Setup for division
                            if (is_8bit) begin
                                dividend = {40'd0, op_high[7:0], op_a[7:0]};
                                divisor = {24'd0, op_b[7:0]};
                            end else if (is_16bit) begin
                                dividend = {32'd0, op_high[15:0], op_a[15:0]};
                                divisor = {16'd0, op_b[15:0]};
                            end else begin
                                dividend = {op_high, op_a};
                                divisor = op_b;
                            end
                            
                            if (divisor == 0) begin
                                divide_error <= 1'b1;
                            end
                        end else begin
                            // Setup for multiplication
                            working_result <= 64'd0;
                            if (is_signed) begin
                                multiplier_state <= {$signed(op_a), 1'b0};
                                multiplicand <= $signed(op_b);
                            end else begin
                                multiplier_state <= {op_a, 1'b0};
                                multiplicand <= {1'b0, op_b};
                            end
                        end
                    end
                end
                
                MUL_CALC: begin
                    // Simplified Booth multiplication (one bit per cycle)
                    if (cycle_count < 32) begin
                        case (multiplier_state[1:0])
                            2'b01: working_result <= working_result + (multiplicand << cycle_count);
                            2'b10: working_result <= working_result - (multiplicand << cycle_count);
                            default: ; // No operation for 00 and 11
                        endcase
                        multiplier_state <= multiplier_state >> 1;
                        cycle_count <= cycle_count + 1;
                    end
                end
                
                DIV_CALC: begin
                    // Non-restoring division algorithm (simplified)
                    if (cycle_count < 32 && !divide_error) begin
                        if (dividend >= divisor) begin
                            dividend <= dividend - divisor;
                            quotient <= (quotient << 1) | 1'b1;
                        end else begin
                            quotient <= quotient << 1;
                        end
                        cycle_count <= cycle_count + 1;
                    end
                end
                
                COMPLETE: begin
                    // Stay in complete state until new operation starts
                end
            endcase
        end
    end
    
    // State transition logic
    always_comb begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start && !divide_error) begin
                    if (is_div) begin
                        next_state = DIV_CALC;
                    end else begin
                        next_state = MUL_CALC;
                    end
                end else if (divide_error) begin
                    next_state = COMPLETE;
                end
            end
            
            MUL_CALC: begin
                if (cycle_count >= 32) begin
                    next_state = COMPLETE;
                end
            end
            
            DIV_CALC: begin
                if (cycle_count >= 32 || divide_error) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                if (start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end
    
    // Output logic
    always_comb begin
        ready = (state == COMPLETE) || (state == IDLE && !start);
        
        if (is_div) begin
            // Division result: quotient in low 32 bits, remainder in high 32 bits
            result = {remainder, quotient[31:0]};
        end else begin
            // Multiplication result
            result = working_result;
        end
        
        // Flags for multiplication (CF and OF set if result doesn't fit in destination size)
        if (!is_div) begin
            if (is_8bit) begin
                cf = (working_result[15:8] != 8'h00) && (working_result[15:8] != 8'hFF || !is_signed);
                of = cf;
            end else if (is_16bit) begin
                cf = (working_result[31:16] != 16'h0000) && (working_result[31:16] != 16'hFFFF || !is_signed);
                of = cf;
            end else begin
                cf = (working_result[63:32] != 32'h00000000) && (working_result[63:32] != 32'hFFFFFFFF || !is_signed);
                of = cf;
            end
        end else begin
            cf = 1'b0;
            of = 1'b0;
        end
    end

endmodule
