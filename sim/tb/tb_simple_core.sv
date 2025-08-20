// Simple testbench for basic CIX-32 functionality
`timescale 1ns/1ps

module tb_simple_core;
    logic clk, rst_n;
    logic [31:0] imem_addr, imem_rdata;
    logic imem_req, imem_ready;
    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic [3:0] dmem_wstrb;
    logic dmem_req, dmem_we, dmem_ready;
    logic irq;
    logic [7:0] irq_vector;
    logic irq_ack;
    logic [31:0] debug_pc, debug_eax, debug_flags;
    logic debug_halted;

    cix32_core_simple dut(
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata), .imem_req(imem_req), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
        .dmem_wstrb(dmem_wstrb), .dmem_req(dmem_req), .dmem_we(dmem_we), .dmem_ready(dmem_ready),
        .irq(irq), .irq_vector(irq_vector), .irq_ack(irq_ack),
        .debug_pc(debug_pc), .debug_eax(debug_eax), .debug_flags(debug_flags), .debug_halted(debug_halted)
    );

    // Clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simple program
    logic [7:0] program[0:15];
    initial begin
        program[0] = 8'h40;  // INC EAX
        program[1] = 8'h40;  // INC EAX  
        program[2] = 8'h48;  // DEC EAX
        program[3] = 8'h40;  // INC EAX
        program[4] = 8'hF4;  // HLT
        program[5] = 8'h90;  // NOP
        program[6] = 8'h90;  // NOP
        program[7] = 8'h90;  // NOP
        program[8] = 8'h90;  // NOP
        program[9] = 8'h90;  // NOP
        program[10] = 8'h90; // NOP
        program[11] = 8'h90; // NOP
        program[12] = 8'h90; // NOP
        program[13] = 8'h90; // NOP
        program[14] = 8'h90; // NOP
        program[15] = 8'h90; // NOP
    end

    // Memory model
    assign imem_rdata = {program[imem_addr[3:0]+3], program[imem_addr[3:0]+2], 
                        program[imem_addr[3:0]+1], program[imem_addr[3:0]]};
    
    always_ff @(posedge clk) begin
        imem_ready <= imem_req;
        dmem_ready <= dmem_req;
    end

    // Test
    initial begin
        rst_n = 0; irq = 0; irq_vector = 0; dmem_rdata = 0;
        imem_ready = 0; dmem_ready = 0;
        #20 rst_n = 1;
        
        wait(debug_halted);
        #50;
        
        $display("Test completed:");
        $display("Final EAX = 0x%08h (expected 0x00000002)", debug_eax);
        $display("Final FLAGS = 0x%08h", debug_flags);
        
        if (debug_eax == 32'h2) $display("PASS");
        else $display("FAIL");
        
        $finish;
    end

    // Waveforms
    initial begin
        $dumpfile("simple_test.vcd");
        $dumpvars(0, tb_simple_core);
    end

endmodule
