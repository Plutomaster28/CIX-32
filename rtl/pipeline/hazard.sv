// Hazard Detection and Forwarding Unit for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_hazard (
    // Pipeline stage inputs
    input  decode_stage_t  decode_stage,
    input  execute_stage_t execute_stage,
    input  memory_stage_t  memory_stage,
    input  writeback_stage_t writeback_stage,
    
    // Stall control outputs
    output logic           stall_fetch,
    output logic           stall_decode,
    output logic           stall_execute,
    output logic           stall_memory,
    output logic           flush_pipeline,
    
    // Forwarding control
    output logic [1:0]     forward_a_sel,  // 00: reg, 01: mem, 10: wb
    output logic [1:0]     forward_b_sel,
    output logic [31:0]    forward_a_data,
    output logic [31:0]    forward_b_data,
    
    // Branch/jump control
    input  logic           branch_taken,
    input  logic           jump_taken
);

    // Data hazard detection
    logic load_use_hazard;
    logic data_hazard_a, data_hazard_b;
    
    // Check for load-use hazard
    always_comb begin
        load_use_hazard = 1'b0;
        
        // If execute stage is a load and decode stage needs the result
        if (execute_stage.valid && 
            (execute_stage.inst.uop == UOP_MOV_RM || execute_stage.inst.uop == UOP_POP) &&
            decode_stage.valid) begin
            
            // Check if decode stage uses the register being loaded
            if ((decode_stage.inst.reg_src && decode_stage.inst.src_reg == execute_stage.inst.dst_reg) ||
                (decode_stage.inst.reg_dst && decode_stage.inst.dst_reg == execute_stage.inst.dst_reg && 
                 decode_stage.inst.uop != UOP_MOV_RI)) begin
                load_use_hazard = 1'b1;
            end
        end
    end
    
    // Data forwarding logic
    always_comb begin
        forward_a_sel = 2'b00; // Default: use register file
        forward_b_sel = 2'b00;
        forward_a_data = 32'h0;
        forward_b_data = 32'h0;
        
        data_hazard_a = 1'b0;
        data_hazard_b = 1'b0;
        
        // Check for data hazards on source A
        if (execute_stage.valid && execute_stage.inst.reg_src) begin
            // Forward from memory stage
            if (memory_stage.valid && memory_stage.inst.reg_dst && 
                memory_stage.inst.dst_reg == execute_stage.inst.src_reg) begin
                forward_a_sel = 2'b01;
                forward_a_data = memory_stage.alu_result;
                data_hazard_a = 1'b1;
            end
            // Forward from writeback stage
            else if (writeback_stage.valid && writeback_stage.inst.reg_dst && 
                     writeback_stage.inst.dst_reg == execute_stage.inst.src_reg) begin
                forward_a_sel = 2'b10;
                forward_a_data = writeback_stage.result;
                data_hazard_a = 1'b1;
            end
        end
        
        // Check for data hazards on source B (for two-operand instructions)
        if (execute_stage.valid && execute_stage.inst.has_modrm && 
            execute_stage.inst.uop != UOP_MOV_MR) begin
            // Forward from memory stage
            if (memory_stage.valid && memory_stage.inst.reg_dst && 
                memory_stage.inst.dst_reg == execute_stage.inst.dst_reg) begin
                forward_b_sel = 2'b01;
                forward_b_data = memory_stage.alu_result;
                data_hazard_b = 1'b1;
            end
            // Forward from writeback stage
            else if (writeback_stage.valid && writeback_stage.inst.reg_dst && 
                     writeback_stage.inst.dst_reg == execute_stage.inst.dst_reg) begin
                forward_b_sel = 2'b10;
                forward_b_data = writeback_stage.result;
                data_hazard_b = 1'b1;
            end
        end
    end
    
    // Control hazard handling
    always_comb begin
        flush_pipeline = branch_taken || jump_taken;
    end
    
    // Stall control
    always_comb begin
        stall_fetch = load_use_hazard;
        stall_decode = load_use_hazard;
        stall_execute = 1'b0; // Can add complex instruction stalls here
        stall_memory = 1'b0;  // Memory stalls handled by LSU
    end

endmodule
