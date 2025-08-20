// Enhanced Instruction Fetch Unit for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_fetch (
    input  logic         clk,
    input  logic         rst_n,
    
    // Program counter and control
    input  logic [31:0]  pc_in,
    input  logic         pc_valid,
    output logic [31:0]  pc_out,
    
    // Branch/jump control
    input  logic         branch_taken,
    input  logic [31:0]  branch_target,
    
    // Halt control
    input  logic         halted,
    
    // Segment information for CS
    input  logic [31:0]  cs_base,
    input  logic [31:0]  cs_limit,
    
    // Instruction memory interface
    output logic [31:0]  imem_addr,
    input  logic [31:0]  imem_rdata,
    output logic         imem_req,
    input  logic         imem_ready,
    
    // Instruction buffer output
    output logic [127:0] inst_bytes,
    output logic [3:0]   valid_bytes,
    output logic         inst_valid,
    input  logic         inst_ready,
    input  logic [3:0]   consumed_bytes // From decoder
);

    // Instruction buffer - holds up to 16 bytes
    logic [127:0] fetch_buffer;
    logic [3:0]   buffer_valid;
    logic [31:0]  current_pc;
    logic [31:0]  fetch_pc;
    
    // Fetch state machine
    typedef enum logic [1:0] {
        FETCH_IDLE,
        FETCH_REQUEST,
        FETCH_WAIT
    } fetch_state_t;
    
    fetch_state_t fetch_state, next_fetch_state;
    
    // PC management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_pc <= 32'h000FFFF0; // x86 reset vector
            fetch_pc <= 32'h000FFFF0;
        end else if (branch_taken) begin
            current_pc <= branch_target;
            fetch_pc <= branch_target;
        end else if (inst_valid && inst_ready) begin
            current_pc <= current_pc + consumed_bytes;
        end
    end
    
    // Fetch buffer management
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            fetch_buffer <= 128'h0;
            buffer_valid <= 4'h0;
            fetch_state <= FETCH_IDLE;
        end else begin
            fetch_state <= next_fetch_state;
            
            case (fetch_state)
                FETCH_IDLE: begin
                    if (!halted && buffer_valid < 4) begin
                        // Need more bytes
                        fetch_pc <= current_pc + buffer_valid;
                    end
                end
                
                FETCH_WAIT: begin
                    if (imem_ready) begin
                        // Shift in new data
                        case (buffer_valid)
                            4'h0: fetch_buffer[31:0] <= imem_rdata;
                            4'h1: fetch_buffer[39:8] <= imem_rdata;
                            4'h2: fetch_buffer[47:16] <= imem_rdata;
                            4'h3: fetch_buffer[55:24] <= imem_rdata;
                            default: fetch_buffer[127:96] <= imem_rdata;
                        endcase
                        buffer_valid <= buffer_valid + 4;
                    end
                end
            endcase
            
            // Consume bytes when instruction is accepted
            if (inst_valid && inst_ready) begin
                fetch_buffer <= fetch_buffer >> (consumed_bytes * 8);
                buffer_valid <= buffer_valid - consumed_bytes;
            end
            
            // Clear buffer on branch
            if (branch_taken) begin
                fetch_buffer <= 128'h0;
                buffer_valid <= 4'h0;
            end
        end
    end
    
    // State transition logic
    always_comb begin
        next_fetch_state = fetch_state;
        
        case (fetch_state)
            FETCH_IDLE: begin
                if (!halted && buffer_valid < 8) begin // Keep buffer reasonably full
                    next_fetch_state = FETCH_REQUEST;
                end
            end
            
            FETCH_REQUEST: begin
                if (imem_ready) begin
                    next_fetch_state = FETCH_IDLE;
                end else begin
                    next_fetch_state = FETCH_WAIT;
                end
            end
            
            FETCH_WAIT: begin
                if (imem_ready) begin
                    next_fetch_state = FETCH_IDLE;
                end
            end
        endcase
    end
    
    // Calculate physical address for fetch
    logic [31:0] physical_fetch_addr;
    always_comb begin
        physical_fetch_addr = cs_base + fetch_pc;
        
        // Check CS limit
        if (fetch_pc > cs_limit) begin
            physical_fetch_addr = 32'hFFFFFFFF; // Will cause fault
        end
    end
    
    // Output assignments
    assign pc_out = current_pc;
    assign imem_addr = physical_fetch_addr;
    assign imem_req = (fetch_state == FETCH_REQUEST || fetch_state == FETCH_WAIT) && !halted;
    
    assign inst_bytes = fetch_buffer;
    assign valid_bytes = (buffer_valid > 4'hF) ? 4'hF : buffer_valid; // Cap at 15 bytes
    assign inst_valid = (buffer_valid >= 4'h1) && !halted; // At least 1 byte available

endmodule
