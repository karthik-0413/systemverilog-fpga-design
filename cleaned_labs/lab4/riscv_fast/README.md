# RISC-V Fast Processor

A multi-cycle RISC-V RV32I processor implementation in SystemVerilog with synchronous BRAM (Block RAM) for instruction and data memory.

## Overview

This project implements a **fast multi-cycle RISC-V processor** that executes the base integer instruction set (RV32I). The processor uses a 4-state state machine:

1. **FETCH_INSTR**: Instruction Fetch from memory
2. **WAIT_INSTR**: Wait for instruction fetch to complete
3. **EXECUTE**: Decode instruction, execute ALU operations, and compute memory addresses
4. **WAIT_MEM**: Wait for memory operations (read/write) to complete

## Architecture

### Core Components

- **riscv_fast.sv**: Main processor core (RV32I ALU and control logic)
- **riscv_top.sv**: Top-level wrapper connecting processor to memory
- **bram.sv**: Synchronous Block RAM for unified instruction/data memory (1KB, 256 words)

### Supported Instructions

The processor supports all RV32I base instructions including:

## Running Simulations

### Assembly Test (`sim/`)

Tests the processor with a hand-written assembly program.

```bash
cd riscv_fast/sim
make sim
```

**What it does:**
- Runs `riscvtest.s` - a comprehensive test of arithmetic, logic, branch, and memory operations
- Tests result: Writes value `25` to memory address `100`
- Expected output: `Simulation succeeded`

### C Program Test (`sim_c/`)

Tests the processor with a C program compiled to RISC-V.

```bash
cd riscv_fast/sim_c
make sim
```

**What it does:**
- Runs a compiled C program on a RISC-V CPU
- Tests basic arithmetic and memory operations in a C program
- Look through the C program in `sim_c/test.c` to see what it does & check the test bench in `sim_c/riscv_c_tb.sv` to see how the test works
- Expected output: `Simulation succeeded - C program result correct!`

### Clean Build

```bash
make clean  # Removes simulation output and generated files
make sim    # Rebuild and run
```

## Memory Map

The processor uses unified memory (instruction and data share same 4KB BRAM):

## Notes

- The processor uses **synchronous writes** and **combinatorial reads** for BRAM
- Each instruction takes 2-4 cycles depending on whether memory access is needed
- Load and store instructions trigger WAIT_MEM state to complete memory operations
- Non-memory instructions proceed directly from EXECUTE to WAIT_INSTR