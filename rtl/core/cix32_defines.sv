// CIX-32 Core Definitions and Constants
`ifndef CIX32_DEFINES_SV
`define CIX32_DEFINES_SV

// Processor modes
typedef enum logic [1:0] {
    MODE_REAL      = 2'b00,
    MODE_PROTECTED = 2'b01,
    MODE_LONG      = 2'b10,
    MODE_RESERVED  = 2'b11
} cpu_mode_t;

// Register encoding
typedef enum logic [2:0] {
    REG_EAX = 3'b000,
    REG_ECX = 3'b001,
    REG_EDX = 3'b010,
    REG_EBX = 3'b011,
    REG_ESP = 3'b100,
    REG_EBP = 3'b101,
    REG_ESI = 3'b110,
    REG_EDI = 3'b111
} gpr_encoding_t;

// Segment register encoding
typedef enum logic [2:0] {
    SEG_ES = 3'b000,
    SEG_CS = 3'b001,
    SEG_SS = 3'b010,
    SEG_DS = 3'b011,
    SEG_FS = 3'b100,
    SEG_GS = 3'b101,
    SEG_RESERVED1 = 3'b110,
    SEG_RESERVED2 = 3'b111
} seg_encoding_t;

// Micro-operation types
typedef enum logic [7:0] {
    UOP_NOP     = 8'h00,
    UOP_HLT     = 8'h01,
    UOP_INC     = 8'h02,
    UOP_DEC     = 8'h03,
    UOP_MOV_RR  = 8'h04,
    UOP_MOV_RM  = 8'h05,
    UOP_MOV_MR  = 8'h06,
    UOP_MOV_RI  = 8'h07,
    UOP_ADD     = 8'h08,
    UOP_SUB     = 8'h09,
    UOP_AND     = 8'h0A,
    UOP_OR      = 8'h0B,
    UOP_XOR     = 8'h0C,
    UOP_CMP     = 8'h0D,
    UOP_TEST    = 8'h0E,
    UOP_PUSH    = 8'h0F,
    UOP_POP     = 8'h10,
    UOP_CALL    = 8'h11,
    UOP_RET     = 8'h12,
    UOP_JMP     = 8'h13,
    UOP_JCC     = 8'h14,
    UOP_SHL     = 8'h15,
    UOP_SHR     = 8'h16,
    UOP_SAR     = 8'h17,
    UOP_ROL     = 8'h18,
    UOP_ROR     = 8'h19,
    UOP_MUL     = 8'h1A,
    UOP_IMUL    = 8'h1B,
    UOP_DIV     = 8'h1C,
    UOP_IDIV    = 8'h1D,
    UOP_INT     = 8'h1E,
    UOP_IRET    = 8'h1F,
    UOP_INVALID = 8'hFF
} uop_type_t;

// ALU operation encoding
typedef enum logic [4:0] {
    ALU_ADD   = 5'h00,
    ALU_SUB   = 5'h01,
    ALU_AND   = 5'h02,
    ALU_OR    = 5'h03,
    ALU_XOR   = 5'h04,
    ALU_SHL   = 5'h05,
    ALU_SHR   = 5'h06,
    ALU_SAR   = 5'h07,
    ALU_ROL   = 5'h08,
    ALU_ROR   = 5'h09,
    ALU_INC   = 5'h0A,
    ALU_DEC   = 5'h0B,
    ALU_CMP   = 5'h0C,
    ALU_TEST  = 5'h0D,
    ALU_PASS_A = 5'h0E,
    ALU_PASS_B = 5'h0F
} alu_op_t;

// Memory operation types
typedef enum logic [2:0] {
    MEM_NOP   = 3'b000,
    MEM_LOAD  = 3'b001,
    MEM_STORE = 3'b010,
    MEM_PUSH  = 3'b011,
    MEM_POP   = 3'b100,
    MEM_FETCH = 3'b101
} mem_op_t;

// Exception vectors
typedef enum logic [7:0] {
    EXC_DIVIDE_ERROR    = 8'h00,
    EXC_DEBUG           = 8'h01,
    EXC_NMI             = 8'h02,
    EXC_BREAKPOINT      = 8'h03,
    EXC_OVERFLOW        = 8'h04,
    EXC_BOUND_RANGE     = 8'h05,
    EXC_INVALID_OPCODE  = 8'h06,
    EXC_DEVICE_NA       = 8'h07,
    EXC_DOUBLE_FAULT    = 8'h08,
    EXC_INVALID_TSS     = 8'h0A,
    EXC_SEGMENT_NP      = 8'h0B,
    EXC_STACK_FAULT     = 8'h0C,
    EXC_GENERAL_PROT    = 8'h0D,
    EXC_PAGE_FAULT      = 8'h0E
} exception_vector_t;

// Instruction prefixes
typedef struct packed {
    logic lock;
    logic repnz;
    logic rep;
    logic [2:0] seg_override;
    logic operand_size;
    logic address_size;
} prefix_t;

// Decoded instruction structure
typedef struct packed {
    uop_type_t uop;
    logic [2:0] dst_reg;
    logic [2:0] src_reg;
    logic [2:0] base_reg;
    logic [2:0] index_reg;
    logic [1:0] scale;
    logic [31:0] displacement;
    logic [31:0] immediate;
    logic [3:0] length;
    logic has_modrm;
    logic has_sib;
    logic mem_op;
    logic reg_dst;
    logic reg_src;
    logic imm_op;
    prefix_t prefix;
} decoded_inst_t;

// Pipeline register structures
typedef struct packed {
    logic [31:0] pc;
    logic [127:0] inst_bytes;
    logic [3:0] valid_bytes;
    logic valid;
} fetch_stage_t;

typedef struct packed {
    logic [31:0] pc;
    decoded_inst_t inst;
    logic valid;
} decode_stage_t;

typedef struct packed {
    logic [31:0] pc;
    decoded_inst_t inst;
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [31:0] mem_addr;
    logic valid;
} execute_stage_t;

typedef struct packed {
    logic [31:0] pc;
    decoded_inst_t inst;
    logic [31:0] alu_result;
    logic [31:0] mem_data;
    logic [31:0] flags_result;
    logic valid;
} memory_stage_t;

typedef struct packed {
    logic [31:0] pc;
    decoded_inst_t inst;
    logic [31:0] result;
    logic [31:0] flags_result;
    logic valid;
} writeback_stage_t;

`endif // CIX32_DEFINES_SV
