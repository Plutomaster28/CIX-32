// Load/Store Unit with Segmented Addressing for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_lsu (
    input  logic         clk,
    input  logic         rst_n,
    
    // CPU mode and segment information
    input  cpu_mode_t    cpu_mode,
    input  logic [31:0]  segment_base,
    input  logic [31:0]  segment_limit,
    input  logic [7:0]   segment_attrs,
    
    // Memory operation request
    input  mem_op_t      mem_op,
    input  logic [31:0]  linear_addr,
    input  logic [31:0]  store_data,
    input  logic [3:0]   byte_enable,
    input  logic         req_valid,
    output logic         req_ready,
    
    // Memory interface
    output logic [31:0]  mem_addr,
    output logic [31:0]  mem_wdata,
    input  logic [31:0]  mem_rdata,
    output logic [3:0]   mem_wstrb,
    output logic         mem_req,
    output logic         mem_we,
    input  logic         mem_ready,
    
    // Load result
    output logic [31:0]  load_data,
    output logic         load_valid,
    
    // Exception signals
    output logic         seg_fault,
    output logic         page_fault,
    output logic [31:0]  fault_addr
);

    // Address calculation and protection
    logic [31:0] physical_addr;
    logic        addr_valid;
    logic        protection_ok;
    
    // Calculate physical address
    always_comb begin
        physical_addr = linear_addr;
        addr_valid = 1'b1;
        protection_ok = 1'b1;
        seg_fault = 1'b0;
        page_fault = 1'b0;
        fault_addr = 32'h0;
        
        case (cpu_mode)
            MODE_REAL: begin
                // Real mode: physical = segment_base + offset
                physical_addr = segment_base + linear_addr;
                
                // Check segment limit (64KB in real mode)
                if (linear_addr > segment_limit) begin
                    seg_fault = 1'b1;
                    fault_addr = linear_addr;
                    addr_valid = 1'b0;
                end
            end
            
            MODE_PROTECTED: begin
                // Protected mode: check segment limits and permissions
                physical_addr = segment_base + linear_addr;
                
                // Check segment limit
                if (linear_addr > segment_limit) begin
                    seg_fault = 1'b1;
                    fault_addr = linear_addr;
                    addr_valid = 1'b0;
                end
                
                // Check segment permissions (simplified)
                if (mem_op == MEM_STORE && !(segment_attrs[1])) begin // Writable bit
                    seg_fault = 1'b1;
                    fault_addr = linear_addr;
                    protection_ok = 1'b0;
                end
            end
            
            default: begin
                addr_valid = 1'b0;
            end
        endcase
    end
    
    // Memory request state machine
    typedef enum logic [1:0] {
        LSU_IDLE,
        LSU_REQUEST,
        LSU_WAIT,
        LSU_COMPLETE
    } lsu_state_t;
    
    lsu_state_t lsu_state, next_lsu_state;
    logic [31:0] pending_load_data;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lsu_state <= LSU_IDLE;
            pending_load_data <= 32'h0;
        end else begin
            lsu_state <= next_lsu_state;
            
            if (lsu_state == LSU_WAIT && mem_ready && mem_op == MEM_LOAD) begin
                pending_load_data <= mem_rdata;
            end
        end
    end
    
    // State transition logic
    always_comb begin
        next_lsu_state = lsu_state;
        
        case (lsu_state)
            LSU_IDLE: begin
                if (req_valid && addr_valid && protection_ok) begin
                    next_lsu_state = LSU_REQUEST;
                end else if (req_valid && (!addr_valid || !protection_ok)) begin
                    next_lsu_state = LSU_COMPLETE; // Fault case
                end
            end
            
            LSU_REQUEST: begin
                if (mem_ready) begin
                    next_lsu_state = LSU_COMPLETE;
                end else begin
                    next_lsu_state = LSU_WAIT;
                end
            end
            
            LSU_WAIT: begin
                if (mem_ready) begin
                    next_lsu_state = LSU_COMPLETE;
                end
            end
            
            LSU_COMPLETE: begin
                if (!req_valid) begin
                    next_lsu_state = LSU_IDLE;
                end
            end
        endcase
    end
    
    // Output logic
    always_comb begin
        // Memory interface
        mem_addr = physical_addr;
        mem_wdata = store_data;
        mem_wstrb = byte_enable;
        mem_req = (lsu_state == LSU_REQUEST || lsu_state == LSU_WAIT) && addr_valid && protection_ok;
        mem_we = (mem_op == MEM_STORE || mem_op == MEM_PUSH);
        
        // Request handshake
        req_ready = (lsu_state == LSU_COMPLETE) || (!addr_valid || !protection_ok);
        
        // Load data output
        load_data = (lsu_state == LSU_COMPLETE) ? pending_load_data : mem_rdata;
        load_valid = (lsu_state == LSU_COMPLETE) && (mem_op == MEM_LOAD || mem_op == MEM_POP);
    end

endmodule
