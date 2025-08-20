// Simplified CIX-32 Core for Initial Testing
`timescale 1ns/1ps

module cix32_core_simple (
    input  logic         clk,
    input  logic         rst_n,
    
    output logic [31:0]  imem_addr,
    input  logic [31:0]  imem_rdata,
    output logic         imem_req,
    input  logic         imem_ready,
    
    output logic [31:0]  dmem_addr,
    output logic [31:0]  dmem_wdata,
    input  logic [31:0]  dmem_rdata,
    output logic [3:0]   dmem_wstrb,
    output logic         dmem_req,
    output logic         dmem_we,
    input  logic         dmem_ready,
    
    input  logic         irq,
    input  logic [7:0]   irq_vector,
    output logic         irq_ack,
    
    output logic [31:0]  debug_pc,
    output logic [31:0]  debug_eax,
    output logic [31:0]  debug_flags,
    output logic         debug_halted
);

    // Simple state machine
    typedef enum logic [2:0] {
        FETCH, DECODE, EXECUTE, HALT
    } state_t;
    
    state_t state, next_state;
    logic [31:0] pc;
    logic [7:0] current_opcode;
    logic [31:0] registers [0:7]; // EAX..EDI
    logic [31:0] eflags;
    logic halted;
    
    // Reset and state machine
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= FETCH;
            pc <= 32'h000FFFF0;
            for (int i = 0; i < 8; i++) registers[i] <= 32'h0;
            eflags <= 32'h2;
            halted <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                FETCH: begin
                    if (imem_ready) begin
                        current_opcode <= imem_rdata[7:0];
                        pc <= pc + 1;
                    end
                end
                
                EXECUTE: begin
                    case (current_opcode)
                        8'h40: begin // INC EAX
                            registers[0] <= registers[0] + 1;
                            eflags[6] <= (registers[0] + 1) == 32'h0; // ZF
                        end
                        8'h48: begin // DEC EAX  
                            registers[0] <= registers[0] - 1;
                            eflags[6] <= (registers[0] - 1) == 32'h0; // ZF
                        end
                        8'hF4: begin // HLT
                            halted <= 1'b1;
                        end
                        default: ; // NOP
                    endcase
                end
            endcase
        end
    end
    
    // State transitions
    always_comb begin
        next_state = state;
        case (state)
            FETCH: if (imem_ready && !halted) next_state = DECODE;
            DECODE: next_state = EXECUTE;
            EXECUTE: next_state = halted ? HALT : FETCH;
            HALT: next_state = HALT;
        endcase
    end
    
    // Memory interface
    assign imem_addr = pc;
    assign imem_req = (state == FETCH) && !halted;
    
    assign dmem_addr = 32'h0;
    assign dmem_wdata = 32'h0;
    assign dmem_wstrb = 4'h0;
    assign dmem_req = 1'b0;
    assign dmem_we = 1'b0;
    
    // Debug outputs
    assign debug_pc = pc;
    assign debug_eax = registers[0];
    assign debug_flags = eflags;
    assign debug_halted = halted;
    assign irq_ack = irq;

endmodule
