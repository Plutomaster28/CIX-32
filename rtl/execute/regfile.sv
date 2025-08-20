// General Purpose Register File with sub-register access (skeleton)
`timescale 1ns/1ps

module cix32_regfile (
    input  logic         clk,
    input  logic         rst_n,

    // Read ports (simple dual)
    input  logic  [2:0]  raddr0,
    output logic [31:0]  rdata0,
    input  logic  [2:0]  raddr1,
    output logic [31:0]  rdata1,

    // Write port
    input  logic  [2:0]  waddr,
    input  logic [31:0]  wdata,
    input  logic  [3:0]  wstrb,   // byte enables for partial updates (for sub-register)
    input  logic         we
);

    logic [31:0] regs[7:0]; // EAX, ECX, EDX, EBX, ESP, EBP, ESI, EDI typical order

    // Reset (could define EAX=0 etc)
    integer i;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i=0; i<8; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (we) begin
            if (wstrb[0]) regs[waddr][7:0]   <= wdata[7:0];
            if (wstrb[1]) regs[waddr][15:8]  <= wdata[15:8];
            if (wstrb[2]) regs[waddr][23:16] <= wdata[23:16];
            if (wstrb[3]) regs[waddr][31:24] <= wdata[31:24];
        end
    end

    assign rdata0 = regs[raddr0];
    assign rdata1 = regs[raddr1];

endmodule
