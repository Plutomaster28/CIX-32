// Basic Verilog testbench for CIX-32 simple core
`timescale 1ns/1ps

module tb_simple_core;
    reg clk, rst_n;
    wire [31:0] imem_addr, imem_rdata;
    wire imem_req, imem_ready;
    wire [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    wire [3:0] dmem_wstrb;
    wire dmem_req, dmem_we, dmem_ready;
    reg irq;
    reg [7:0] irq_vector;
    wire irq_ack;
    wire [31:0] debug_pc, debug_eax, debug_flags;
    wire debug_halted;

    cix32_core_simple dut(
        .clk(clk), .rst_n(rst_n),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata), .imem_req(imem_req), .imem_ready(imem_ready),
        .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_rdata(dmem_rdata),
        .dmem_wstrb(dmem_wstrb), .dmem_req(dmem_req), .dmem_we(dmem_we), .dmem_ready(dmem_ready),
        .irq(irq), .irq_vector(irq_vector), .irq_ack(irq_ack),
        .debug_pc(debug_pc), .debug_eax(debug_eax), .debug_flags(debug_flags), .debug_halted(debug_halted)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Simple program memory
    reg [7:0] program [0:15];
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

    // Memory interface
    assign imem_rdata = {program[imem_addr[3:0]+3], program[imem_addr[3:0]+2], 
                        program[imem_addr[3:0]+1], program[imem_addr[3:0]]};
    assign dmem_rdata = 32'h0;
    
    reg imem_ready_reg, dmem_ready_reg;
    assign imem_ready = imem_ready_reg;
    assign dmem_ready = dmem_ready_reg;
    
    always @(posedge clk) begin
        imem_ready_reg <= imem_req;
        dmem_ready_reg <= dmem_req;
    end

    // Test sequence
    initial begin
        rst_n = 0; 
        irq = 0; 
        irq_vector = 0;
        imem_ready_reg = 0; 
        dmem_ready_reg = 0;
        
        #20 rst_n = 1;
        
        // Wait for halt or timeout
        #1000;
        
        $display("Test completed:");
        $display("Final PC = 0x%08h", debug_pc);
        $display("Final EAX = 0x%08h (expected 0x00000002)", debug_eax);
        $display("Final FLAGS = 0x%08h", debug_flags);
        $display("Halted = %b", debug_halted);
        
        if (debug_eax == 32'h2 && debug_halted) begin
            $display("PASS: Test completed successfully");
        end else begin
            $display("FAIL: Unexpected result");
        end
        
        $finish;
    end

    // Monitor execution
    always @(posedge clk) begin
        if (rst_n && imem_req && imem_ready) begin
            $display("[%0t] PC=0x%08h, Opcode=0x%02h, EAX=0x%08h", 
                     $time, debug_pc, program[imem_addr[3:0]], debug_eax);
        end
    end

    // Generate waveforms
    initial begin
        $dumpfile("simple_test.vcd");
        $dumpvars(0, tb_simple_core);
    end

endmodule
