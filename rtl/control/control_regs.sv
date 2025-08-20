// Control Register File for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_control_regs (
    input  logic         clk,
    input  logic         rst_n,

    // Control register access
    input  logic [2:0]   cr_addr,
    input  logic [31:0]  cr_wdata,
    output logic [31:0]  cr_rdata,
    input  logic         cr_we,
    input  logic         cr_re,

    // Mode and state outputs
    output cpu_mode_t    cpu_mode,
    output logic         paging_enabled,
    output logic         protection_enabled,
    output logic         interrupt_enabled,
    output logic [31:0]  page_directory_base,

    // Exception handling
    input  logic         exception_req,
    input  logic [7:0]   exception_vector,
    output logic         exception_ack,

    // Interrupt handling
    input  logic         interrupt_req,
    input  logic [7:0]   interrupt_vector,
    output logic         interrupt_ack
);

    // Control Registers
    logic [31:0] cr0, cr1, cr2, cr3, cr4;
    
    // CR0 bit definitions
    logic pe, mp, em, ts, et, ne, wp, am, nw, cd, pg;
    assign pe = cr0[0];   // Protection Enable
    assign mp = cr0[1];   // Monitor Coprocessor
    assign em = cr0[2];   // Emulation
    assign ts = cr0[3];   // Task Switched
    assign et = cr0[4];   // Extension Type
    assign ne = cr0[5];   // Numeric Error
    assign wp = cr0[16];  // Write Protect
    assign am = cr0[18];  // Alignment Mask
    assign nw = cr0[29];  // Not Write-through
    assign cd = cr0[30];  // Cache Disable
    assign pg = cr0[31];  // Paging

    // CR4 bit definitions
    logic vme, pvi, tsd, de, pse, pae, mce, pge, pce, osfxsr, osxmmexcpt;
    assign vme = cr4[0];       // Virtual-8086 Mode Extensions
    assign pvi = cr4[1];       // Protected-Mode Virtual Interrupts
    assign tsd = cr4[2];       // Time Stamp Disable
    assign de  = cr4[3];       // Debugging Extensions
    assign pse = cr4[4];       // Page Size Extensions
    assign pae = cr4[5];       // Physical Address Extension
    assign mce = cr4[6];       // Machine-Check Enable
    assign pge = cr4[7];       // Page Global Enable
    assign pce = cr4[8];       // Performance-Monitoring Counter Enable
    assign osfxsr = cr4[9];    // Operating System Support for FXSAVE/FXRSTOR
    assign osxmmexcpt = cr4[10]; // Operating System Support for Unmasked SIMD Exceptions

    // Mode determination
    always_comb begin
        if (!pe) begin
            cpu_mode = MODE_REAL;
        end else begin
            cpu_mode = MODE_PROTECTED; // Simplified: no long mode yet
        end
    end

    assign paging_enabled = pg & pe;
    assign protection_enabled = pe;
    assign interrupt_enabled = 1'b1; // Simplified: always enabled for now
    assign page_directory_base = cr3 & 32'hFFFFF000; // Page directory base address

    // Control register read/write
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cr0 <= 32'h60000010; // Reset value: CD=1, NW=1, ET=1
            cr1 <= 32'h00000000; // Reserved
            cr2 <= 32'h00000000; // Page fault linear address
            cr3 <= 32'h00000000; // Page directory base
            cr4 <= 32'h00000000; // Initially all features disabled
        end else if (cr_we) begin
            case (cr_addr)
                3'h0: cr0 <= cr_wdata;
                3'h1: cr1 <= cr_wdata; // Usually reserved
                3'h2: cr2 <= cr_wdata;
                3'h3: cr3 <= cr_wdata;
                3'h4: cr4 <= cr_wdata;
                default: ; // Ignore writes to non-existent registers
            endcase
        end
    end

    // Control register read
    always_comb begin
        case (cr_addr)
            3'h0: cr_rdata = cr0;
            3'h1: cr_rdata = cr1;
            3'h2: cr_rdata = cr2;
            3'h3: cr_rdata = cr3;
            3'h4: cr_rdata = cr4;
            default: cr_rdata = 32'h00000000;
        endcase
    end

    // Exception and interrupt handling (simplified)
    assign exception_ack = exception_req; // Immediate acknowledgment for now
    assign interrupt_ack = interrupt_req;  // Immediate acknowledgment for now

endmodule
