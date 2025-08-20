#!/usr/bin/env python3
"""
CIX-32 Core Test Generator
Generates directed tests for x86 instruction validation
"""

import random
import struct
from enum import Enum
from typing import List, Tuple, Dict

class X86Instruction:
    """Represents an x86 instruction for test generation"""
    
    def __init__(self, mnemonic: str, opcode: int, operands: List[str] = None):
        self.mnemonic = mnemonic
        self.opcode = opcode
        self.operands = operands or []
        self.bytes = []
    
    def encode(self) -> List[int]:
        """Encode instruction to bytes"""
        return [self.opcode] + self.bytes

class TestGenerator:
    """Generates test programs for CIX-32 validation"""
    
    def __init__(self):
        self.instructions = []
        self.expected_results = {}
    
    def add_instruction(self, instr: X86Instruction):
        """Add instruction to test program"""
        self.instructions.append(instr)
    
    def generate_arithmetic_test(self) -> List[int]:
        """Generate arithmetic instruction test"""
        program = []
        
        # Test INC/DEC
        program.extend([0x40])  # INC EAX
        program.extend([0x40])  # INC EAX  
        program.extend([0x48])  # DEC EAX
        
        # Test MOV immediate (simplified)
        program.extend([0xB8, 0x78, 0x56, 0x34, 0x12])  # MOV EAX, 0x12345678
        
        # Test ADD/SUB
        program.extend([0x41])  # INC ECX
        program.extend([0x42])  # INC EDX
        
        # Test stack operations
        program.extend([0x50])  # PUSH EAX
        program.extend([0x58])  # POP EAX
        
        # End with halt
        program.extend([0xF4])  # HLT
        
        return program
    
    def generate_memory_test(self) -> List[int]:
        """Generate memory access test"""
        program = []
        
        # Load immediate
        program.extend([0xB8, 0x00, 0x10, 0x00, 0x00])  # MOV EAX, 0x1000
        
        # Memory operations would go here
        # For now, just basic reg operations
        program.extend([0x40])  # INC EAX
        program.extend([0x50])  # PUSH EAX
        program.extend([0x58])  # POP EAX
        
        program.extend([0xF4])  # HLT
        return program
    
    def generate_branch_test(self) -> List[int]:
        """Generate branch/jump test"""
        program = []
        
        # Simple forward jump test
        program.extend([0x40])  # INC EAX
        program.extend([0xEB, 0x02])  # JMP +2 (skip next instruction)
        program.extend([0x48])  # DEC EAX (should be skipped)
        program.extend([0x40])  # INC EAX (target)
        program.extend([0xF4])  # HLT
        
        return program
    
    def generate_flag_test(self) -> List[int]:
        """Generate flag setting test"""
        program = []
        
        # Test zero flag
        program.extend([0xB8, 0x01, 0x00, 0x00, 0x00])  # MOV EAX, 1
        program.extend([0x48])  # DEC EAX (should set ZF)
        
        # Test overflow
        program.extend([0xB8, 0xFF, 0xFF, 0xFF, 0x7F])  # MOV EAX, 0x7FFFFFFF
        program.extend([0x40])  # INC EAX (should set OF)
        
        program.extend([0xF4])  # HLT
        return program
    
    def write_memory_image(self, program: List[int], filename: str):
        """Write program to memory image file"""
        with open(filename, 'w') as f:
            f.write("// Generated test program for CIX-32\n")
            f.write("// Memory initialization file\n\n")
            
            for i, byte_val in enumerate(program):
                f.write(f"mem[{i:3d}] = 8'h{byte_val:02X};  // {self._disassemble_byte(i, byte_val)}\n")
    
    def _disassemble_byte(self, addr: int, byte_val: int) -> str:
        """Simple disassembly for comments"""
        opcodes = {
            0x40: "INC EAX", 0x41: "INC ECX", 0x42: "INC EDX", 0x43: "INC EBX",
            0x48: "DEC EAX", 0x49: "DEC ECX", 0x4A: "DEC EDX", 0x4B: "DEC EBX",
            0x50: "PUSH EAX", 0x51: "PUSH ECX", 0x58: "POP EAX", 0x59: "POP ECX",
            0x90: "NOP", 0xF4: "HLT", 0xB8: "MOV EAX,imm32", 0xEB: "JMP rel8"
        }
        return opcodes.get(byte_val, f"DATA({byte_val:02X})")

def main():
    """Generate test files"""
    gen = TestGenerator()
    
    # Generate different test types
    tests = {
        "arithmetic": gen.generate_arithmetic_test(),
        "memory": gen.generate_memory_test(), 
        "branch": gen.generate_branch_test(),
        "flags": gen.generate_flag_test()
    }
    
    # Write test files
    for test_name, program in tests.items():
        filename = f"sim/tb/test_{test_name}.mem"
        gen.write_memory_image(program, filename)
        print(f"Generated {filename} ({len(program)} bytes)")
    
    # Generate comprehensive test
    comprehensive = []
    for test_prog in tests.values():
        comprehensive.extend(test_prog[:-1])  # Remove HLT from each
    comprehensive.append(0xF4)  # Add final HLT
    
    gen.write_memory_image(comprehensive, "sim/tb/test_comprehensive.mem")
    print(f"Generated sim/tb/test_comprehensive.mem ({len(comprehensive)} bytes)")

if __name__ == "__main__":
    main()
