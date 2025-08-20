// EFLAGS Register (subset) management
`timescale 1ns/1ps

module cix32_flags (
    input  logic         clk,
    input  logic         rst_n,

    // Write interface from ALU results
    input  logic         set_valid,
    input  logic         set_cf,
    input  logic         set_zf,
    input  logic         set_sf,
    input  logic         set_of,
    input  logic         set_pf,
    input  logic         set_af,
    input  logic  [31:0] ext_mask,   // bits to update (1 = update)

    output logic [31:0]  eflags_out
);

    // Track only low 16 bits early; others optional later.
    logic [31:0] eflags;

    // Reset: IF=0, reserved bits? We'll just zero.
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            eflags <= 32'd2; // bit1 always 1 in x86 architectural reads
        end else if (set_valid) begin
            // Compose new flag bits we currently model
            logic [31:0] new_flags = eflags;
            if (ext_mask[0])  new_flags[0]  = set_cf; // CF
            if (ext_mask[2])  new_flags[2]  = set_pf; // PF
            if (ext_mask[4])  new_flags[4]  = set_af; // AF
            if (ext_mask[6])  new_flags[6]  = set_zf; // ZF
            if (ext_mask[7])  new_flags[7]  = set_sf; // SF
            if (ext_mask[11]) new_flags[11] = set_of; // OF
            // Keep bit1 = 1
            new_flags[1] = 1'b1;
            eflags <= new_flags;
        end
    end

    assign eflags_out = eflags;

endmodule
