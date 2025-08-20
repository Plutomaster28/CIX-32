// Minimal working x86 core for demonstration
module cix32_demo (
    input wire clk,
    input wire rst_n,
    output reg [31:0] pc,
    output reg [31:0] eax,
    output reg halted
);

    reg [7:0] memory [0:255];
    reg [2:0] state;
    reg [7:0] opcode;
    
    initial begin
        memory[0] = 8'h40;  // INC EAX
        memory[1] = 8'h40;  // INC EAX  
        memory[2] = 8'h48;  // DEC EAX
        memory[3] = 8'h40;  // INC EAX
        memory[4] = 8'hF4;  // HLT
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
            eax <= 32'h0;
            halted <= 1'b0;
            state <= 3'h0;
        end else if (!halted) begin
            case (state)
                3'h0: begin // Fetch
                    opcode <= memory[pc[7:0]];
                    state <= 3'h1;
                end
                3'h1: begin // Execute
                    case (opcode)
                        8'h40: eax <= eax + 1; // INC EAX
                        8'h48: eax <= eax - 1; // DEC EAX
                        8'hF4: halted <= 1'b1; // HLT
                    endcase
                    if (opcode != 8'hF4) begin
                        pc <= pc + 1;
                        state <= 3'h0;
                    end
                end
            endcase
        end
    end

endmodule

module tb_demo;
    reg clk, rst_n;
    wire [31:0] pc, eax;
    wire halted;
    
    cix32_demo dut(clk, rst_n, pc, eax, halted);
    
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    initial begin
        rst_n = 0;
        #20 rst_n = 1;
        
        wait(halted);
        #20;
        
        $display("CIX-32 Demo Results:");
        $display("Final PC: 0x%08h", pc);
        $display("Final EAX: 0x%08h", eax);
        $display("Expected EAX: 0x00000002");
        
        if (eax == 32'h2) $display("✅ TEST PASSED");
        else $display("❌ TEST FAILED");
        
        $finish;
    end
    
    initial begin
        $dumpfile("cix32_demo.vcd");
        $dumpvars(0, tb_demo);
    end

endmodule
