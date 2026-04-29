# Lab 4: Multi-Cycle RV32I Processor - Part 1: Simulation

## Overview

In this lab, you will complete the design of a **multi-cycle RV32I processor** that executes in 2-4 cycles per instruction and can run compiled C programs on an FPGA (with Part 2). Part 1 focuses on getting the processor working correctly in simulation.

### Learning Objectives

- Design efficient multi-cycle processor and handle complex FSM control
- Implement the complete RV32I instruction set in hardware
- Verify correctness through simulation with assembly and C programs
- Work with BRAM (Block RAM) for instruction and data storage
- Implement and test on FPGA (Part 2)

### Lab Timeline

- **Part 1** (1 week): Complete CPU design and verify in simulation
- **Part 2** (1 week): Implement on FPGA and verify on hardware

## Part 1: Simulation

### Background

You are provided with a **skeleton processor** in `riscv_fast/rtl/riscv_fast.sv` that includes:

- **FSM (Finite State Machine)** with 4 states: FETCH_INSTR, WAIT_INSTR, EXECUTE, WAIT_MEM
- **Register file** (32 x 32-bit registers)
- **ALU** structure and signal declarations
- **BRAM interface** signals for memory access
- **Variables** for instruction fields, immediates, and control signals

Your job is to **complete the implementation** by filling in the missing instruction decodings, ALU operations, control logic, and state machine behavior.

### Required Files

- `CPU_brief.md` - Architecture overview and FSM explanation (provided separately)
- `riscv_fast/rtl/riscv_fast.sv` - CPU skeleton to complete
- `riscv_fast/rtl/bram.sv` - BRAM module (provided)
- `riscv_fast/rtl/riscv_top.sv` - Top-level wrapper (provided)

## Tasks

### Task 1: Complete the CPU Design

**File**: `riscv_fast/rtl/riscv_fast.sv`

You need to implement:

1. **Instruction Decoding**
   - Decode all RV32I opcodes (load, store, ALU reg, ALU imm, branch, jump, etc.)
   - Extract instruction fields (rs1, rs2, rd, immediate types)

2. **ALU Operations**
   - Arithmetic: ADD, SUB, SLT, SLTI, SLTU, SLTIU
   - Logic: AND, OR, XOR, ANDI, ORI, XORI
   - Shifts: SLL, SRL, SRA, SLLI, SRLI, SRAI
   - Other: LUI, AUIPC

3. **Memory Operations (Already provided. Read and understand the variants)**
   - Load: LW (word load)
   - Store: SW (word store)
   - Compute load/store addresses: rs1 + immediate offset
   - Generate write masks for byte-level writes

4. **Branch and Jump Logic**
   - BEQ, BNE, BLT, BGE, BLTU, BGEU
   - JAL, JALR
   - Compute next PC based on branch/jump conditions

5. **State Machine**
   - **FETCH_INSTR**: Initiate instruction fetch
   - **WAIT_INSTR**: Wait for instruction to arrive, then latch it
   - **EXECUTE**: Decode, execute ALU, compute addresses, control register writes
   - **WAIT_MEM**: Wait for memory operations to complete
   - Manage state transitions based on instruction type (memory vs non-memory)

6. **Register Writeback**
   - Determine when and what to write back (ALU result, load data, PC+4, etc.)
   - Handle x0 (always zero)
   - Ensure register writes happen only at the right time

### Task 2: Verify Assembly Test

**Test**: `riscv_fast/sim/` - Assembly program test

1. Navigate to `riscv_fast/sim/`:
   ```bash
   cd riscv_fast/sim
   ```

2. Run the simulation:
   ```bash
   make sim
   ```

3. **Expected Result**:
   - Simulation runs without errors (same as lab 3)
   - Output shows: `Simulation succeeded`
   - The processor correctly executes `riscvtest.s` and writes value 25 to memory address 100

4. **What this test checks**:
   - Arithmetic operations (add, sub, addi)
   - Logic operations (and, or)
   - Branches (beq)
   - Jumps (jal)
   - Load/Store (lw, sw)
   - Shifts (srai, sra)

5. **If test fails**:
   - check the simulation log (xsim.log) which prints various details to track CPU execution
   - Check the simulation log / output for which instruction fails
   - Verify your instruction decoding is correct
   - Check ALU outputs and register values
   - Use waveform viewer to debug timing issues

### Task 3: Verify C Program Test

**Test**: `riscv_fast/sim_c/` - Compiled C program test

1. **Compile the C program**:
   - Navigate to `test_programs/test1/` and follow the README
   - This generates a `program.verilog.hex` hex file to load into BRAM
   - Copy the generated hex to `riscv_fast/sim_c/riscvtest.txt` (look at README.md & Makefile for help)

2. **Run the simulation**:
   ```bash
   cd riscv_fast/sim_c
   make sim
   ```

3. **Expected Result**:
   - Simulation runs without errors
   - Output shows: `Simulation succeeded - C program result correct!`
   - The processor correctly runs compiled C code and produces the expected result

4. **What this test checks**:
   - Your CPU can run real compiled C programs
   - More complex sequences of instructions
   - Realistic memory usage patterns

### Task 4: Write an Extended C Test Program (2 days)

**Location**: Create `test_programs/test2/` (or similar)

1. **Requirements**:
   - Write a C program that exercises as many RV32I instructions as possible
   - Cover instruction types not well-tested in test1:
     - Different shift amounts (SLL, SRL, SRA)
     - More branch conditions (BNE, BLT, BGE, BLTU, BGEU)
     - Multiple loads and stores
     - JALR instruction
     - Edge cases (x0 register, negative numbers, bit operations)

2. **Format**:
   - Follow the same structure as `test_programs/test1/`
   - Compile to RISC-V hex using the provided build system
   - Store result in highest memory location (0x4000) for testbench to check

3. **Testing**:
   - Create testbench: `riscv_fast/sim_c_test2/riscv_c_tb.sv` (can copy from sim_c)
   - Update expected value in testbench
   - Verify with: `cd riscv_fast/sim_c_test2 && make sim`

4. **Example instruction coverage checklist**:
   - [ ] SLL, SRL, SRA with various shift amounts
   - [ ] BNE, BLT, BGE (not just BEQ)
   - [ ] Multiple sequential loads
   - [ ] Multiple sequential stores
   - [ ] JALR with different register values
   - [ ] Chained operations (result of one instruction feeds into next)
   - [ ] Negative number arithmetic
   - [ ] Bitwise operations (AND, OR, XOR)

## Deliverables

### Part 1 Submission

1. **Completed CPU**: `riscv_fast/rtl/riscv_fast.sv`
   - All instructions implemented
   - Clean, readable code with comments

2. **Test Results**:
   - Assembly test passes: `riscv_fast/sim/` output shows "Simulation succeeded"
   - C test passes: `riscv_fast/sim_c/` output shows "Simulation succeeded - C program result correct!"
   - Extended C test passes: Custom test program works correctly

3. **Documentation**:
   - Add any notes about your implementation in `riscv_fast/rtl/riscv_fast.sv` header comments
   - Record test results and any issues encountered

4. **Extended Test Program**:
   - Source code in `test_programs/test2/` (or similar)
   - Compiled hex file ready to load
   - Working testbench with correct expected value

## Reference Documents

- **CPU Architecture**: See `CPU_brief.md` for:
  - FSM state diagrams and transitions
  - Signal descriptions
  - Instruction execution examples
  - Memory vs non-memory instruction timing

- **Processor README**: `riscv_fast/README.md`
  - How to run simulations
  - Memory map
  - Waveform viewing instructions

- **RISC-V Specification**: Refer to the RV32I base instruction set
  - Instruction encoding
  - Immediate formats (I, S, B, U, J types)
  - Register conventions

## Tips

1. **Use the log file to track execution**
   - Check `riscv_fast/sim/xsim.log` for simulation output
   - Look for "Simulation succeeded" message

3. **Use the waveform viewer**
   - Run with `make sim` then open `wave.wdb` in Vivado
   - Inspect signals at each cycle to debug timing
   - Check register values and memory addresses

4. **Watch for off-by-one errors**
   - Address calculations: PC+4, immediate offsets, shifts
   - Register indexing
   - State machine transitions

5. **Memory timing**
   - BRAM reads have 1 cycle latency (apply address, get data next cycle)
   - BRAM writes are synchronous (happen on clock edge)
   - Plan the timing carefully in your FSM (when to store inst, when to update PC, when to read from reg file)

6. **Review the skeleton comments**
   - The provided skeleton has notes about what each section does
   - Read these carefully before implementing


**Next**: After Part 1 is complete and all tests pass, move to **Part 2: FPGA Implementation**.
