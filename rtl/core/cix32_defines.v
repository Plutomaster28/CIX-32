// CIX-32 Core Definitions and Constants - Verilog Compatible
`ifndef CIX32_DEFINES_V
`define CIX32_DEFINES_V

// Processor modes
`define MODE_REAL      2'b00
`define MODE_PROTECTED 2'b01
`define MODE_LONG      2'b10
`define MODE_RESERVED  2'b11

// Register encoding
`define REG_EAX 3'b000
`define REG_ECX 3'b001
`define REG_EDX 3'b010
`define REG_EBX 3'b011
`define REG_ESP 3'b100
`define REG_EBP 3'b101
`define REG_ESI 3'b110
`define REG_EDI 3'b111

// Segment register encoding
`define SEG_ES 3'b000
`define SEG_CS 3'b001
`define SEG_SS 3'b010
`define SEG_DS 3'b011
`define SEG_FS 3'b100
`define SEG_GS 3'b101

// Micro-operation types
`define UOP_NOP     8'h00
`define UOP_HLT     8'h01
`define UOP_INC     8'h02
`define UOP_DEC     8'h03
`define UOP_MOV_RR  8'h04
`define UOP_MOV_RM  8'h05
`define UOP_MOV_MR  8'h06
`define UOP_MOV_RI  8'h07
`define UOP_ADD     8'h08
`define UOP_SUB     8'h09
`define UOP_AND     8'h0A
`define UOP_OR      8'h0B
`define UOP_XOR     8'h0C
`define UOP_CMP     8'h0D
`define UOP_TEST    8'h0E
`define UOP_JMP     8'h0F
`define UOP_JZ      8'h10
`define UOP_JNZ     8'h11
`define UOP_PUSH    8'h12
`define UOP_POP     8'h13

// ALU operation encoding  
`define ALU_NOP   5'h00
`define ALU_ADD   5'h01
`define ALU_SUB   5'h02
`define ALU_AND   5'h03
`define ALU_OR    5'h04
`define ALU_XOR   5'h05
`define ALU_SHL   5'h06
`define ALU_SHR   5'h07
`define ALU_SAR   5'h08
`define ALU_ROL   5'h09
`define ALU_ROR   5'h0A
`define ALU_INC   5'h0B
`define ALU_DEC   5'h0C
`define ALU_NEG   5'h0D
`define ALU_NOT   5'h0E
`define ALU_CMP   5'h0F
`define ALU_TEST  5'h10
`define ALU_MOV   5'h11

// FPU operation encoding
`define FPU_FADD   4'h0
`define FPU_FSUB   4'h1
`define FPU_FMUL   4'h2
`define FPU_FDIV   4'h3
`define FPU_FSQRT  4'h4
`define FPU_FCMP   4'h5
`define FPU_FLD    4'h6
`define FPU_FST    4'h7

// SIMD operation encoding
`define SIMD_PADD   4'h0
`define SIMD_PSUB   4'h1
`define SIMD_PMUL   4'h2
`define SIMD_PAND   4'h3
`define SIMD_POR    4'h4
`define SIMD_PXOR   4'h5
`define SIMD_PSHL   4'h6
`define SIMD_PSHR   4'h7

// Condition codes
`define CC_O   4'h0  // Overflow
`define CC_NO  4'h1  // No overflow
`define CC_B   4'h2  // Below (unsigned less than)
`define CC_NB  4'h3  // Not below
`define CC_E   4'h4  // Equal (zero)
`define CC_NE  4'h5  // Not equal
`define CC_BE  4'h6  // Below or equal
`define CC_A   4'h7  // Above
`define CC_S   4'h8  // Sign
`define CC_NS  4'h9  // No sign
`define CC_PE  4'hA  // Parity even
`define CC_PO  4'hB  // Parity odd
`define CC_L   4'hC  // Less than (signed)
`define CC_GE  4'hD  // Greater or equal
`define CC_LE  4'hE  // Less or equal
`define CC_G   4'hF  // Greater than

// Flag register bits
`define FLAG_CF  0   // Carry flag
`define FLAG_PF  2   // Parity flag
`define FLAG_AF  4   // Auxiliary carry flag
`define FLAG_ZF  6   // Zero flag
`define FLAG_SF  7   // Sign flag
`define FLAG_TF  8   // Trap flag
`define FLAG_IF  9   // Interrupt flag
`define FLAG_DF  10  // Direction flag
`define FLAG_OF  11  // Overflow flag

// Memory operation types
`define MEM_BYTE  2'b00
`define MEM_WORD  2'b01
`define MEM_DWORD 2'b10

`endif // CIX32_DEFINES_V
