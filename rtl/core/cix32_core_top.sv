// CIX-32 Top-Level Core with Full Pipeline Implementation
// SPDX-License-Identifier: UNLICENSED (decide license later)

`timescale 1ns/1ps
`include "cix32_defines.sv"

module cix32_core_top (
    input  logic         clk,
    input  logic         rst_n,

    // Instruction memory interface
    output logic [31:0]  imem_addr,
    input  logic [31:0]  imem_rdata,
    output logic         imem_req,
    input  logic         imem_ready,

    // Data memory interface
    output logic [31:0]  dmem_addr,
    output logic [31:0]  dmem_wdata,
    input  logic [31:0]  dmem_rdata,
    output logic [3:0]   dmem_wstrb,
    output logic         dmem_req,
    output logic         dmem_we,
    input  logic         dmem_ready,

    // Interrupt and exception interface
    input  logic         irq,
    input  logic [7:0]   irq_vector,
    output logic         irq_ack,
    
    // Debug interface
    output logic [31:0]  debug_pc,
    output logic [31:0]  debug_eax,
    output logic [31:0]  debug_flags,
    output logic         debug_halted
);

    // ------------------------------------------------------------------
    // Core State and Control
    // ------------------------------------------------------------------
    logic halted;
    cpu_mode_t cpu_mode;
    logic [31:0] current_pc;
    
    // Pipeline stages
    fetch_stage_t    fetch_stage_in, fetch_stage_out;
    decode_stage_t   decode_stage_in, decode_stage_out;
    execute_stage_t  execute_stage_in, execute_stage_out;
    memory_stage_t   memory_stage_in, memory_stage_out;
    writeback_stage_t writeback_stage_in, writeback_stage_out;
    
    // Pipeline control
    logic stall_fetch, stall_decode, stall_execute, stall_memory, flush_pipeline;
    logic branch_taken, jump_taken;
    logic [31:0] branch_target;
    
    // ------------------------------------------------------------------
    // Control and Segment Registers
    // ------------------------------------------------------------------
    logic [31:0] cr_rdata;
    logic [15:0] seg_rdata;
    logic [31:0] seg_base, seg_limit;
    logic [7:0]  seg_attrs;
    logic [31:0] cs_base, cs_limit;
    logic [15:0] cs_reg;
    
    cix32_control_regs u_control_regs (
        .clk(clk), .rst_n(rst_n),
        .cr_addr(3'h0), .cr_wdata(32'h0), .cr_rdata(cr_rdata),
        .cr_we(1'b0), .cr_re(1'b0),
        .cpu_mode(cpu_mode),
        .paging_enabled(),
        .protection_enabled(),
        .interrupt_enabled(),
        .page_directory_base(),
        .exception_req(1'b0), .exception_vector(8'h0), .exception_ack(),
        .interrupt_req(irq), .interrupt_vector(irq_vector), .interrupt_ack(irq_ack)
    );
    
    cix32_segment_regs u_segment_regs (
        .clk(clk), .rst_n(rst_n),
        .seg_addr(3'h1), .seg_wdata(16'h0), .seg_rdata(seg_rdata), .seg_we(1'b0),
        .seg_sel(3'h1), .seg_base(cs_base), .seg_limit(cs_limit), .seg_attrs(),
        .cpu_mode(cpu_mode)
    );
    
    assign cs_reg = seg_rdata;
    
    // ------------------------------------------------------------------
    // Instruction Fetch Unit
    // ------------------------------------------------------------------
    logic [127:0] fetch_bytes;
    logic [3:0]   fetch_valid_bytes;
    logic         fetch_inst_valid;
    logic         fetch_inst_ready;
    logic [3:0]   consumed_bytes;
    
    cix32_fetch u_fetch (
        .clk(clk), .rst_n(rst_n),
        .pc_in(current_pc), .pc_valid(1'b1), .pc_out(current_pc),
        .branch_taken(branch_taken), .branch_target(branch_target),
        .halted(halted),
        .cs_base(cs_base), .cs_limit(cs_limit),
        .imem_addr(imem_addr), .imem_rdata(imem_rdata), 
        .imem_req(imem_req), .imem_ready(imem_ready),
        .inst_bytes(fetch_bytes), .valid_bytes(fetch_valid_bytes),
        .inst_valid(fetch_inst_valid), .inst_ready(fetch_inst_ready),
        .consumed_bytes(consumed_bytes)
    );
    
    // ------------------------------------------------------------------
    // Instruction Decoder
    // ------------------------------------------------------------------
    decoded_inst_t decoded_inst;
    logic          decode_inst_valid;
    logic          decode_inst_ready;
    
    cix32_decoder u_decoder (
        .clk(clk), .rst_n(rst_n),
        .bytes_in(fetch_bytes), .valid_bytes(fetch_valid_bytes),
        .in_valid(fetch_inst_valid), .in_ready(fetch_inst_ready),
        .decoded_inst(decoded_inst), .inst_valid(decode_inst_valid), .inst_ready(decode_inst_ready),
        .cpu_mode(cpu_mode), .cs_reg(cs_reg)
    );
    
    assign consumed_bytes = decode_inst_valid ? decoded_inst.length : 4'h0;
    
    // ------------------------------------------------------------------
    // Register File
    // ------------------------------------------------------------------
    logic [31:0] reg_rdata0, reg_rdata1;
    logic [2:0]  reg_raddr0, reg_raddr1;
    logic [2:0]  reg_waddr;
    logic [31:0] reg_wdata;
    logic [3:0]  reg_wstrb;
    logic        reg_we;
    
    cix32_regfile u_regfile (
        .clk(clk), .rst_n(rst_n),
        .raddr0(reg_raddr0), .rdata0(reg_rdata0),
        .raddr1(reg_raddr1), .rdata1(reg_rdata1),
        .waddr(reg_waddr), .wdata(reg_wdata), .wstrb(reg_wstrb), .we(reg_we)
    );
    
    // ------------------------------------------------------------------
    // ALU and Execution Units
    // ------------------------------------------------------------------
    logic [31:0] alu_result;
    logic [63:0] alu_result_wide;
    logic alu_cf, alu_zf, alu_sf, alu_of, alu_pf, alu_af;
    logic alu_valid;
    
    cix32_alu u_alu (
        .alu_op(ALU_ADD), // Will be controlled by execution logic
        .op_a(reg_rdata0), .op_b(reg_rdata1),
        .shift_amount(5'h0), .carry_in(1'b0),
        .is_8bit(1'b0), .is_16bit(decoded_inst.prefix.operand_size),
        .result(alu_result), .result_wide(alu_result_wide),
        .cf(alu_cf), .zf(alu_zf), .sf(alu_sf), .of(alu_of), .pf(alu_pf), .af(alu_af),
        .valid_result(alu_valid)
    );
    
    // ------------------------------------------------------------------
    // Flags Register
    // ------------------------------------------------------------------
    logic [31:0] eflags;
    logic        flags_update;
    
    cix32_flags u_flags (
        .clk(clk), .rst_n(rst_n),
        .set_valid(flags_update),
        .set_cf(alu_cf), .set_zf(alu_zf), .set_sf(alu_sf),
        .set_of(alu_of), .set_pf(alu_pf), .set_af(alu_af),
        .ext_mask(32'h0000_0DCF), // Update arithmetic flags
        .eflags_out(eflags)
    );
    
    // ------------------------------------------------------------------
    // Load/Store Unit
    // ------------------------------------------------------------------
    logic [31:0] lsu_load_data;
    logic        lsu_load_valid;
    logic        lsu_seg_fault, lsu_page_fault;
    logic [31:0] lsu_fault_addr;
    
    cix32_lsu u_lsu (
        .clk(clk), .rst_n(rst_n),
        .cpu_mode(cpu_mode),
        .segment_base(seg_base), .segment_limit(seg_limit), .segment_attrs(seg_attrs),
        .mem_op(MEM_NOP), .linear_addr(32'h0), .store_data(32'h0), .byte_enable(4'h0),
        .req_valid(1'b0), .req_ready(),
        .mem_addr(dmem_addr), .mem_wdata(dmem_wdata), .mem_rdata(dmem_rdata),
        .mem_wstrb(dmem_wstrb), .mem_req(dmem_req), .mem_we(dmem_we), .mem_ready(dmem_ready),
        .load_data(lsu_load_data), .load_valid(lsu_load_valid),
        .seg_fault(lsu_seg_fault), .page_fault(lsu_page_fault), .fault_addr(lsu_fault_addr)
    );
    
    // ------------------------------------------------------------------
    // Pipeline Control and Hazard Detection
    // ------------------------------------------------------------------
    logic [1:0] forward_a_sel, forward_b_sel;
    logic [31:0] forward_a_data, forward_b_data;
    
    cix32_hazard u_hazard (
        .decode_stage(decode_stage_out), .execute_stage(execute_stage_out),
        .memory_stage(memory_stage_out), .writeback_stage(writeback_stage_out),
        .stall_fetch(stall_fetch), .stall_decode(stall_decode),
        .stall_execute(stall_execute), .stall_memory(stall_memory),
        .flush_pipeline(flush_pipeline),
        .forward_a_sel(forward_a_sel), .forward_b_sel(forward_b_sel),
        .forward_a_data(forward_a_data), .forward_b_data(forward_b_data),
        .branch_taken(branch_taken), .jump_taken(jump_taken)
    );
    
    cix32_pipeline u_pipeline (
        .clk(clk), .rst_n(rst_n),
        .stall_fetch(stall_fetch), .stall_decode(stall_decode),
        .stall_execute(stall_execute), .stall_memory(stall_memory),
        .flush_pipeline(flush_pipeline),
        .fetch_in(fetch_stage_in), .fetch_out(fetch_stage_out),
        .decode_in(decode_stage_in), .decode_out(decode_stage_out),
        .execute_in(execute_stage_in), .execute_out(execute_stage_out),
        .memory_in(memory_stage_in), .memory_out(memory_stage_out),
        .writeback_in(writeback_stage_in), .writeback_out(writeback_stage_out)
    );
    
    // ------------------------------------------------------------------
    // Pipeline Stage Logic
    // ------------------------------------------------------------------
    
    // Fetch stage input
    always_comb begin
        fetch_stage_in.pc = current_pc;
        fetch_stage_in.inst_bytes = fetch_bytes;
        fetch_stage_in.valid_bytes = fetch_valid_bytes;
        fetch_stage_in.valid = fetch_inst_valid && !stall_fetch;
    end
    
    // Decode stage input
    always_comb begin
        decode_stage_in.pc = fetch_stage_out.pc;
        decode_stage_in.inst = decoded_inst;
        decode_stage_in.valid = decode_inst_valid && !stall_decode;
        decode_inst_ready = !stall_decode;
    end
    
    // Execute stage input
    always_comb begin
        execute_stage_in.pc = decode_stage_out.pc;
        execute_stage_in.inst = decode_stage_out.inst;
        execute_stage_in.valid = decode_stage_out.valid && !stall_execute;
        
        // Operand forwarding
        case (forward_a_sel)
            2'b00: execute_stage_in.operand_a = reg_rdata0;
            2'b01: execute_stage_in.operand_a = forward_a_data;
            2'b10: execute_stage_in.operand_a = forward_a_data;
            default: execute_stage_in.operand_a = reg_rdata0;
        endcase
        
        case (forward_b_sel)
            2'b00: execute_stage_in.operand_b = reg_rdata1;
            2'b01: execute_stage_in.operand_b = forward_b_data;
            2'b10: execute_stage_in.operand_b = forward_b_data;
            default: execute_stage_in.operand_b = reg_rdata1;
        endcase
        
        execute_stage_in.mem_addr = 32'h0; // Will be calculated in execute
    end
    
    // Register file address generation
    always_comb begin
        if (decode_stage_out.valid) begin
            reg_raddr0 = decode_stage_out.inst.dst_reg;
            reg_raddr1 = decode_stage_out.inst.src_reg;
        end else begin
            reg_raddr0 = 3'h0;
            reg_raddr1 = 3'h0;
        end
    end
    
    // Memory stage input
    always_comb begin
        memory_stage_in.pc = execute_stage_out.pc;
        memory_stage_in.inst = execute_stage_out.inst;
        memory_stage_in.alu_result = alu_result;
        memory_stage_in.mem_data = lsu_load_data;
        memory_stage_in.flags_result = eflags;
        memory_stage_in.valid = execute_stage_out.valid && !stall_memory;
    end
    
    // Writeback stage input  
    always_comb begin
        writeback_stage_in.pc = memory_stage_out.pc;
        writeback_stage_in.inst = memory_stage_out.inst;
        writeback_stage_in.result = memory_stage_out.alu_result;
        writeback_stage_in.flags_result = memory_stage_out.flags_result;
        writeback_stage_in.valid = memory_stage_out.valid;
    end
    
    // Writeback logic
    always_comb begin
        reg_we = writeback_stage_out.valid && writeback_stage_out.inst.reg_dst;
        reg_waddr = writeback_stage_out.inst.dst_reg;
        reg_wdata = writeback_stage_out.result;
        reg_wstrb = writeback_stage_out.inst.prefix.operand_size ? 4'b0011 : 4'b1111;
        
        flags_update = writeback_stage_out.valid && 
                      (writeback_stage_out.inst.uop == UOP_ADD ||
                       writeback_stage_out.inst.uop == UOP_SUB ||
                       writeback_stage_out.inst.uop == UOP_INC ||
                       writeback_stage_out.inst.uop == UOP_DEC ||
                       writeback_stage_out.inst.uop == UOP_AND ||
                       writeback_stage_out.inst.uop == UOP_OR ||
                       writeback_stage_out.inst.uop == UOP_XOR ||
                       writeback_stage_out.inst.uop == UOP_CMP ||
                       writeback_stage_out.inst.uop == UOP_TEST);
    end
    
    // Halt detection
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            halted <= 1'b0;
        end else if (writeback_stage_out.valid && writeback_stage_out.inst.uop == UOP_HLT) begin
            halted <= 1'b1;
        end
    end
    
    // Branch/jump logic (simplified)
    always_comb begin
        branch_taken = 1'b0;
        jump_taken = 1'b0;
        branch_target = 32'h0;
        
        if (execute_stage_out.valid) begin
            case (execute_stage_out.inst.uop)
                UOP_JMP: begin
                    jump_taken = 1'b1;
                    branch_target = execute_stage_out.pc + execute_stage_out.inst.immediate;
                end
                UOP_CALL: begin
                    jump_taken = 1'b1;
                    branch_target = execute_stage_out.pc + execute_stage_out.inst.immediate;
                end
                UOP_RET: begin
                    jump_taken = 1'b1;
                    branch_target = execute_stage_out.operand_a; // From stack
                end
                default: ;
            endcase
        end
    end
    
    // Debug outputs
    assign debug_pc = current_pc;
    assign debug_eax = reg_rdata0; // Assuming EAX is register 0
    assign debug_flags = eflags;
    assign debug_halted = halted;

endmodule
