# CIX-32 Microarchitecture Overview (Draft)

## Philosophy
Incremental, test-driven growth from a tiny real-mode subset toward richer x86 compliance. Use clear internal micro-ops, keep pipeline shallow early, then extend.

## Initial Pipeline (Phase 1-3)
Single-cycle fetch + decode + execute (sequential) to reduce complexity. Later evolve into 5-stage:
1. IF: Fetch bytes, queue into instruction buffer (handles variable length). 
2. ID: Prefix strip, decode, ModR/M + SIB parse, immediate extraction, micro-op formation.
3. EX: ALU / branch / effective address calc.
4. MEM: Data memory read/write, page walk assist.
5. WB: Register write, flag commit, retirement.

A future uop buffer / reordering is optional but out-of-scope first passes.

## Register Files
- General Purpose: 8 x 32-bit (EAX..EDI). Sub-register mapping handled by byte/word lanes.
- Segment Registers: CS, DS, SS, ES, FS, GS. Real mode: base = selector << 4.
- Control: CR0..CR4 (start with CR0.PE and PG bits only meaningful).
- Flags: EFLAGS (subset initially).
- FPU Stack: 8 x 80-bit (later milestone).
- XMM: 8 or 16 x 128-bit (SSE baseline) later.

## Decode Strategy
1. Prefix scan up to 4 legacy prefixes.
2. Opcode byte (1-3 bytes) recognition.
3. ModR/M parse (register/memory fields).
4. SIB (if needed), displacement (1/2/4 bytes), immediate (1/2/4 bytes).
5. Internal micro-op expansion (e.g., string ops -> looped uops).

## Memory & Addressing
Effective address: base + (index * scale) + displacement + segment_base. Real mode: segment_base = seg << 4. Protected mode adds descriptor lookup (later). Paging adds linear->physical translation via TLB.

## Exceptions & Interrupts (Later)
Vector table (IDT) with minimal descriptor fields first. Deliver faults precisely at retirement.

## FPU & SIMD (Later)
Separate pipeline stage or co-issue once integer path stable. Start with basic x87 operations, then add XMM register file and a handful of SSE instructions.

## Verification Approach
- Directed tests for each instruction variant.
- Random instruction streams (constrained) against a reference emulator (e.g., Bochs/QEMU) in lockstep (later addition; requires DPI or trace compare).
- Formal (SymbiYosys) for selected modules (ALU flags, register file, control FSMs).

## OpenROAD Considerations
- Keep module boundaries cohesive for floorplanning (frontend, execute, memory, control).
- Limit multi-cycle paths; add clear pipeline regs before introduction of complex bypass networks.
- Parameterize for optional features to reduce gatecount for early P&R.

## Next Steps (Immediate)
- Implement register file with sub-register write-masking.
- Integrate decoder + ALU + simple execution path updating a register.
- Add flag register and correct INC/DEC semantics.
- Add minimal HLT handling (stop fetch) and testbench observation.
