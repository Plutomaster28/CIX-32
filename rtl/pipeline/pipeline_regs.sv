// Pipeline Registers and Control for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_pipeline (
    input  logic         clk,
    input  logic         rst_n,
    
    // Pipeline control
    input  logic         stall_fetch,
    input  logic         stall_decode,
    input  logic         stall_execute,
    input  logic         stall_memory,
    input  logic         flush_pipeline,
    
    // Fetch stage
    input  fetch_stage_t   fetch_in,
    output fetch_stage_t   fetch_out,
    
    // Decode stage  
    input  decode_stage_t  decode_in,
    output decode_stage_t  decode_out,
    
    // Execute stage
    input  execute_stage_t execute_in,
    output execute_stage_t execute_out,
    
    // Memory stage
    input  memory_stage_t  memory_in,
    output memory_stage_t  memory_out,
    
    // Writeback stage
    input  writeback_stage_t writeback_in,
    output writeback_stage_t writeback_out
);

    // Fetch -> Decode pipeline register
    fetch_stage_t fetch_decode_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_pipeline) begin
            fetch_decode_reg <= '0;
        end else if (!stall_decode) begin
            if (!stall_fetch) begin
                fetch_decode_reg <= fetch_in;
            end else begin
                fetch_decode_reg.valid <= 1'b0; // Insert bubble
            end
        end
    end
    
    assign fetch_out = fetch_decode_reg;
    
    // Decode -> Execute pipeline register
    decode_stage_t decode_execute_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_pipeline) begin
            decode_execute_reg <= '0;
        end else if (!stall_execute) begin
            if (!stall_decode) begin
                decode_execute_reg <= decode_in;
            end else begin
                decode_execute_reg.valid <= 1'b0; // Insert bubble
            end
        end
    end
    
    assign decode_out = decode_execute_reg;
    
    // Execute -> Memory pipeline register
    execute_stage_t execute_memory_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_pipeline) begin
            execute_memory_reg <= '0;
        end else if (!stall_memory) begin
            if (!stall_execute) begin
                execute_memory_reg <= execute_in;
            end else begin
                execute_memory_reg.valid <= 1'b0; // Insert bubble
            end
        end
    end
    
    assign execute_out = execute_memory_reg;
    
    // Memory -> Writeback pipeline register
    memory_stage_t memory_writeback_reg;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_pipeline) begin
            memory_writeback_reg <= '0;
        end else begin
            memory_writeback_reg <= memory_in;
        end
    end
    
    assign memory_out = memory_writeback_reg;
    
    // Writeback output (no register needed)
    assign writeback_out = writeback_in;

endmodule
