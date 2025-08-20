// Segment Register File for CIX-32
`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_segment_regs (
    input  logic         clk,
    input  logic         rst_n,

    // Segment register access
    input  logic [2:0]   seg_addr,
    input  logic [15:0]  seg_wdata,
    output logic [15:0]  seg_rdata,
    input  logic         seg_we,

    // Segment base calculation
    input  logic [2:0]   seg_sel,
    output logic [31:0]  seg_base,
    output logic [31:0]  seg_limit,
    output logic [7:0]   seg_attrs,

    // CPU mode input
    input  cpu_mode_t    cpu_mode
);

    // Segment registers (visible portion - selectors)
    logic [15:0] cs, ds, ss, es, fs, gs;
    
    // In real mode, segment base = selector << 4
    // In protected mode, we'd need descriptor table lookup (simplified here)
    logic [31:0] segment_bases[0:5];
    logic [31:0] segment_limits[0:5];
    logic [7:0]  segment_attributes[0:5];

    // Reset values
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cs <= 16'hF000; // Reset CS
            ds <= 16'h0000;
            ss <= 16'h0000;
            es <= 16'h0000;
            fs <= 16'h0000;
            gs <= 16'h0000;
        end else if (seg_we) begin
            case (seg_addr)
                SEG_ES: es <= seg_wdata;
                SEG_CS: cs <= seg_wdata;
                SEG_SS: ss <= seg_wdata;
                SEG_DS: ds <= seg_wdata;
                SEG_FS: fs <= seg_wdata;
                SEG_GS: gs <= seg_wdata;
                default: ; // Ignore invalid writes
            endcase
        end
    end

    // Segment register read
    always_comb begin
        case (seg_addr)
            SEG_ES: seg_rdata = es;
            SEG_CS: seg_rdata = cs;
            SEG_SS: seg_rdata = ss;
            SEG_DS: seg_rdata = ds;
            SEG_FS: seg_rdata = fs;
            SEG_GS: seg_rdata = gs;
            default: seg_rdata = 16'h0000;
        endcase
    end

    // Calculate segment bases (real mode: selector << 4, protected mode: descriptor lookup)
    always_comb begin
        case (cpu_mode)
            MODE_REAL: begin
                segment_bases[0] = {16'h0000, es[15:0]} << 4;  // ES
                segment_bases[1] = {16'h0000, cs[15:0]} << 4;  // CS
                segment_bases[2] = {16'h0000, ss[15:0]} << 4;  // SS
                segment_bases[3] = {16'h0000, ds[15:0]} << 4;  // DS
                segment_bases[4] = {16'h0000, fs[15:0]} << 4;  // FS
                segment_bases[5] = {16'h0000, gs[15:0]} << 4;  // GS
                
                // In real mode, segment limit is 64KB-1
                for (int i = 0; i < 6; i++) begin
                    segment_limits[i] = 32'h0000FFFF;
                    segment_attributes[i] = 8'h93; // Present, writable, accessed
                end
            end
            
            MODE_PROTECTED: begin
                // Simplified protected mode: use selectors as-is for now
                // In real implementation, this would involve GDT/LDT lookup
                segment_bases[0] = {16'h0000, es[15:0]};
                segment_bases[1] = {16'h0000, cs[15:0]};
                segment_bases[2] = {16'h0000, ss[15:0]};
                segment_bases[3] = {16'h0000, ds[15:0]};
                segment_bases[4] = {16'h0000, fs[15:0]};
                segment_bases[5] = {16'h0000, gs[15:0]};
                
                for (int i = 0; i < 6; i++) begin
                    segment_limits[i] = 32'hFFFFFFFF; // 4GB limit
                    segment_attributes[i] = 8'h93;    // Present, writable, accessed
                end
            end
            
            default: begin
                for (int i = 0; i < 6; i++) begin
                    segment_bases[i] = 32'h00000000;
                    segment_limits[i] = 32'h00000000;
                    segment_attributes[i] = 8'h00;
                end
            end
        endcase
    end

    // Output the selected segment's properties
    assign seg_base  = segment_bases[seg_sel];
    assign seg_limit = segment_limits[seg_sel];
    assign seg_attrs = segment_attributes[seg_sel];

endmodule
