# CIX-32 Core Project

An educational / experimental 32-bit x86-compatible subset soft-core named **CIX-32**, targeting open-source ASIC flow (OpenROAD, 180nm) and FPGA prototyping.

> Ambition: Eventually support real mode + protected mode, paging, x87 FPU, and selected SIMD (SSE baseline) while remaining understandable & verifiable but without implementing the entirety of x86 since I don't have the money nor guts to challenge Intel or AMD.

## High-Level Milestones (Incremental Roadmap)
1. **M0: Infrastructure & Minimal Core Skeleton**
   - Module scaffolds, build scripts, simple testbench, CI hooks.
2. **M1: Real Mode Minimal Execution**
   - 16-bit fetch/decode/execute for a tiny subset: MOV, ADD, SUB, INC, DEC, JMP, CALL, RET, PUSH, POP, basic flags.
3. **M2: 32-bit Transition + Core GPR + Flags**
   - Enter protected mode (simplified), implement EAX..EDI, segment regs visible, full flag logic for basic ALU.
4. **M3: Memory + Stack + Interrupts**
   - IDT-like minimal mechanism, INT/IRET, stack semantics, basic PIC model.
5. **M4: Paging (Optional early)**
   - CR0.PG, CR3 walk (simplified, no PSE yet), TLB.
6. **M5: Integer Multiply/Divide + Barrel Shifter/Rotator**
7. **M6: Expanded Instruction Decode (Core integer set)**
8. **M7: x87 FPU (basic subset: load/store, add/sub/mul/div, compare)**
9. **M8: SSE Register File & Minimal SIMD**
10. **M9: Pipeline Optimizations (Forwarding, simple branch prediction)**
11. **M10: Exceptions, Debug, Performance Counters**
12. **M11: Synthesis/OpenROAD Flow Scripts & Timing Closure @180nm**

## Directory Layout
```
rtl/
  frontend/   # fetch, predecode, i-cache (future)
  decode/     # decoder, prefix handling, micro-op expansion
  execute/    # ALU, shifter, mul/div, flag logic, branch unit
  fpu/        # x87 pipeline & control (later)
  pipeline/   # pipeline registers, hazard + forwarding logic
  memory/     # load/store unit, data cache / bus IF, MMU/TLB
  control/    # control regs, modes, exceptions, interrupt ctrl
  core/       # top-level core wrapper integrating submodules
  bus/        # shared bus protocols (simple for now, AXI/AHB later)
 sim/
  tb/         # testbenches
 docs/        # specs, microarchitecture notes, diagrams
```

## Minimal Initial Subset (Target for First Running Instructions)
- 16-bit real mode (reset state) subset of instructions: `MOV r16, imm16`, `MOV r/m16, r16`, `MOV r16, r/m16`, `ADD`, `SUB`, `INC`, `DEC`, `JMP rel16`, `NOP`, `PUSH r16`, `POP r16`, `CALL rel16`, `RET`, `HLT`.
- Flags tracked: CF, ZF, SF, OF, PF, AF (AF optional early).