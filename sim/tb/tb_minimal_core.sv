// Enhanced Testbench for CIX-32 Core
`timescale 1ns/1ps
`include "cix32_defines.sv"

module tb_minimal_core;
    logic clk; 
    logic rst_n;

    // Instruction memory
    logic [31:0] imem_rdata;
    logic [31:0] imem_addr;
    logic        imem_req;
    logic        imem_ready;

    // Data memory
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0]  dmem_wstrb;
    logic        dmem_req, dmem_we, dmem_ready;

    // Interrupt and debug
    logic        irq;
    logic [7:0]  irq_vector;
    logic        irq_ack;
    logic [31:0] debug_pc, debug_eax, debug_flags;
    logic        debug_halted;

    // DUT instance
    cix32_core_top dut(
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata), .imem_req(imem_req), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata), 
        .dmem_wstrb(dmem_wstrb), .dmem_req(dmem_req), .dmem_we(dmem_we), .dmem_ready(dmem_ready),
        .irq(irq), .irq_vector(irq_vector), .irq_ack(irq_ack),
        .debug_pc(debug_pc), .debug_eax(debug_eax), .debug_flags(debug_flags), .debug_halted(debug_halted)
    );

    // Clock generation - 100MHz
    initial begin
        clk = 0; 
        forever #5 clk = ~clk;
    end

    // Simple program memory with x86 instructions
    logic [7:0] program_memory [0:1023];
    
    initial begin
        // Initialize program memory with a simple test program
        // Reset all memory first
        for (int i = 0; i < 1024; i++) begin
            program_memory[i] = 8'h90; // NOP
        end
        
        // Test program starting at reset vector 0xFFFF0
        // This would normally map to high memory, but we'll use lower addresses for sim
        program_memory[0]  = 8'h40;  // INC EAX
        program_memory[1]  = 8'h40;  // INC EAX  
        program_memory[2]  = 8'h48;  // DEC EAX
        program_memory[3]  = 8'hB8;  // MOV EAX, imm32 (simplified, just opcode)
        program_memory[4]  = 8'h78;  // immediate low byte
        program_memory[5]  = 8'h56;  // immediate 
        program_memory[6]  = 8'h34;  // immediate
        program_memory[7]  = 8'h12;  // immediate high byte (0x12345678)
        program_memory[8]  = 8'h41;  // INC ECX
        program_memory[9]  = 8'h42;  // INC EDX
        program_memory[10] = 8'h50;  // PUSH EAX
        program_memory[11] = 8'h58;  // POP EAX
        program_memory[12] = 8'h90;  // NOP
        program_memory[13] = 8'h90;  // NOP
        program_memory[14] = 8'hF4;  // HLT
        program_memory[15] = 8'h90;  // NOP (should not execute)
    end

    // Instruction memory model
    always_comb begin
        // Map high addresses to low memory for simulation
        logic [31:0] local_addr = imem_addr & 32'h000003FF; // Mask to 1KB
        imem_rdata = {program_memory[local_addr+3], 
                     program_memory[local_addr+2], 
                     program_memory[local_addr+1], 
                     program_memory[local_addr]};
    end

    // Simple ready generator for instruction memory
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_ready <= 1'b0;
        end else begin
            imem_ready <= imem_req; // 1-cycle latency
        end
    end

    // Data memory model (simple RAM)
    logic [31:0] data_memory [0:255];
    logic [31:0] stack_pointer;
    
    initial begin
        for (int i = 0; i < 256; i++) begin
            data_memory[i] = 32'h00000000;
        end
        stack_pointer = 32'h1000; // Initial stack pointer
    end

    // Data memory interface
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_ready <= 1'b0;
            dmem_rdata <= 32'h0;
        end else begin
            dmem_ready <= dmem_req;
            
            if (dmem_req && dmem_we) begin
                // Write operation
                logic [7:0] addr_idx = dmem_addr[9:2]; // Word-aligned
                if (dmem_wstrb[0]) data_memory[addr_idx][7:0]   <= dmem_wdata[7:0];
                if (dmem_wstrb[1]) data_memory[addr_idx][15:8]  <= dmem_wdata[15:8];
                if (dmem_wstrb[2]) data_memory[addr_idx][23:16] <= dmem_wdata[23:16];
                if (dmem_wstrb[3]) data_memory[addr_idx][31:24] <= dmem_wdata[31:24];
            end else if (dmem_req) begin
                // Read operation
                dmem_rdata <= data_memory[dmem_addr[9:2]];
            end
        end
    end

    // Test control and monitoring
    integer cycle_count;
    integer instruction_count;
    logic [31:0] prev_pc;
    
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 0;
            instruction_count <= 0;
            prev_pc <= 32'h000FFFF0;
        end else begin
            cycle_count <= cycle_count + 1;
            
            // Count instructions (when PC changes)
            if (debug_pc != prev_pc) begin
                instruction_count <= instruction_count + 1;
                prev_pc <= debug_pc;
                $display("[INST %0d] PC=0x%08h, EAX=0x%08h, FLAGS=0x%08h", 
                         instruction_count, debug_pc, debug_eax, debug_flags);
            end
        end
    end

    // Reset sequence
    initial begin
        rst_n = 0; 
        irq = 0; 
        irq_vector = 8'h0;
        
        #50; 
        rst_n = 1;
        $display("[TB] Reset released, starting execution...");
    end

    // Test assertions and checks
    always @(posedge clk) begin
        if (rst_n) begin
            // Check for halt condition
            if (debug_halted) begin
                $display("[TB] Core halted after %0d cycles, %0d instructions", 
                         cycle_count, instruction_count);
                
                // Check expected results
                if (debug_eax == 32'h12345679) begin // Expected: started 0, inc twice, dec once, then loaded 0x12345678, inc once more
                    $display("[PASS] EAX has expected value");
                end else begin
                    $display("[FAIL] EAX = 0x%08h, expected 0x12345679", debug_eax);
                end
                
                #100;
                $display("[TB] Test completed");
                $finish;
            end
            
            // Timeout check
            if (cycle_count > 10000) begin
                $display("[TIMEOUT] Test exceeded maximum cycles");
                $finish;
            end
        end
    end

    // Waveform dump
    initial begin
        $dumpfile("cix32_core.vcd");
        $dumpvars(0, tb_minimal_core);
    end

    // Interrupt test (optional)
    initial begin
        #2000;
        if (!debug_halted) begin
            $display("[TB] Sending test interrupt...");
            irq = 1'b1;
            irq_vector = 8'h20; // Timer interrupt
            #20;
            irq = 1'b0;
        end
    end

endmodule
