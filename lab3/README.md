# Lab 3: RISC-V Processor Implementation

## Overview

This lab involves implementing RISC-V processor designs at two different abstraction levels:
- **Part 1 (25 points)**: Single-Cycle Processor - Implement `addi` and `jal` instructions
- **Part 2 (75 points)**: Multi-Cycle Processor - Implement the full control and datapath logic

## Part 1: Single-Cycle Processor (25 points)

### Objective
Implement the `addi` (Add Immediate) and `jal` (Jump and Link) instructions in an incomplete single-cycle RISC-V processor.

### Directory Structure
```
riscv_single_cycle/
├── rtl/
│   └── riscvsingle_incomplete.sv    # Incomplete RTL (!!! complete this & rename to riscvsingle.sv!!!)
├── sim/
│   ├── riscvsingle_tb.sv            # Testbench
│   ├── run_simulation.sh            # Shell script to run simulation
│   ├── run_simulation.tcl           # Vivado batch script
│   ├── run_gui.tcl                  # GUI simulation script
│   ├── clean.sh                     # Cleanup script
│   ├── Makefile                     # Makefile for build targets
│   └── riscvtest.txt                # Test program
└── README.md                        # See for detailed architecture info
```

### What's Already Implemented
- Complete datapath (ALU, register file, multiplexers)
- Memory system (instruction and data memories)
- Other instruction decoders (lw, sw, R-type, beq)
- Parts of PC update logic & ALU operations and control


### Implementation Guide

1. **Study the existing code**: Understand how other instructions are decoded
2. **Decode `addi`** (opcode: `7'b0010011`):
   - This is an I-type instruction. Set the control signals accourdingly.
3. **Decode `jal`** (opcode: `7'b1101111`):
   - This is a J-type instruction. Set the control signals accourdingly.
4. **Implement immediate extension** for J-type format

### Testing
Run the simulation to verify your implementation:

```bash
cd riscv_single_cycle/sim
make sim          # Compile, elaborate, and run
# or
./run_simulation.sh
```

**Expected output**:
```
Memory write: Address[0x00000060] = 0x00000007 (7)
Memory write: Address[0x00000064] = 0x00000019 (25)
Simulation succeeded
```

### Grading Rubric (25 points)
- **Control decoder for `addi`**: 5 points
- **Control decoder for `jal`**: 5 points
- **Immediate extension for J-type**: 5 points
- **Testbench passes**: 10 points

### Debugging Tips
- Check the control signal encoding in other instructions
- Verify immediate extension format matches RISC-V spec
- Monitor waveforms to see when each instruction executes
- Use `$display` statements to track values

---

## Part 2: Multi-Cycle Processor (75 points)

### Objective
Implement a complete multi-cycle RISC-V processor using a finite state machine (FSM) approach. Students implement the control unit, datapath components, and FSM.

### Directory Structure
```
riscv_multi_cycle/
├── rtl/
│   ├── riscvmulti.sv               # Main processor module (incomplete)
├── sim/
│   ├── riscvmulti_tb.sv            # Testbench
│   ├── run_simulation.sh           # Shell script to run simulation
│   ├── run_simulation.tcl          # Vivado batch script
│   ├── run_gui.tcl                 # GUI simulation script
│   ├── clean.sh                    # Cleanup script
│   ├── Makefile                    # Makefile for build targets
│   └── riscvtest.txt               # Test program
└── README.md                       # See for detailed architecture info
```

### What's Already Provided
- Top-level module structure
- Memory modules (imem, dmem)
- Testbench
- Can reuse components from Part 1 as needed

### What You Need to Implement

#### 1. **Controller FSM** 
Implement the finite state machine that controls instruction execution:

**States to implement**:
- `FETCH` - Load instruction from memory
- `DECODE` - Decode instruction and read registers
- `MEMADR` - Calculate memory address
- `MEMREAD` - Read from memory
- `MEMWRITE` - Write to memory
- `MEMWB` - Write memory data to register
- `EXECUTER` - Execute R-type instruction
- `EXECUTEI` - Execute I-type ALU instruction
- `ALUWB` - Write ALU result to register
- `BEQ` - Execute branch
- `JAL` - Execute jump and link

**FSM outputs**:
- `ALUSrcA`, `ALUSrcB` - ALU input selection
- `ResultSrc` - Result mux control
- `AdrSrc` - Address mux control
- `IRWrite`, `PCWrite` - Register write enables
- `RegWrite`, `MemWrite` - Memory write control
- `ALUOp` - ALU operation
- `Branch` - Branch signal

#### 2. **Datapath & Decoder** 
Reuse portions from Part 1 and implement the additional logic & registers as needed.

#### 4. **Integration and Testing** 
- Connect all modules correctly
- Verify simulation passes
- All instructions execute properly

### Supported Instructions
- **R-Type**: add, sub, and, or, slt
- **I-Type**: addi, andi, ori, slti, lw
- **S-Type**: sw
- **B-Type**: beq
- **J-Type**: jal

Start with the datapath from single cycle design - Modify as needed for multi-cycle design. Connect everything and test. Debug with waveforms as needed.

### Testing
```bash
cd riscv_multi_cycle/sim
make sim          # Compile, elaborate, and run
# or
./run_simulation.sh
```

**Expected output**:
```
Memory write: Address[0x00000060] = 0x00000007 (7)
Memory write: Address[0x00000064] = 0x00000019 (25)
Simulation succeeded
```

### Grading Rubric (75 points)

| Component | Points | Criteria |
|-----------|--------|----------|
| **Controller FSM** | 30 | All states implemented, correct transitions, proper control signals |
| **Datapath** | 10 | All registers/muxes, proper data flow, immediate extension |
| **Decoders** | 10 | ALU decoder, instruction decoder working correctly |
| **Simulation Pass** | 20 | Testbench passes with correct output |

### Debugging Tips
- Use waveform viewer to trace state transitions
- Print signals at each state boundary
- Verify immediate formats match RISC-V spec
- Check mux select signals match expected values
- Monitor register writes to ensure data flows correctly
- Test with simpler programs first as needed (single instruction and then small group of 2-5 instructions)
  Note: If you cannot get the full CPU working showing indivigual instructions working will get you partial credits

---

## General Lab Information

### File Organization
- **rtl/**: Register transfer level (hardware) design files
- **sim/**: Simulation files (testbench, scripts)

### How to Run Simulations

**Method 1: Using Makefile (Recommended)**
```bash
cd riscv_single_cycle/sim  # or riscv_multi_cycle/sim
make sim      # Run simulation
make clean    # Clean up files
make help     # Show available targets
```

**Method 2: Shell Script**
```bash
cd riscv_*/sim
chmod +x run_simulation.sh
./run_simulation.sh
```

**Method 3: Vivado TCL**
```bash
cd riscv_*/sim
vivado -mode batch -source run_simulation.tcl
```

**Method 4: Manual xsim**
```bash
cd riscv_*/sim
xvlog -sv ../rtl/*.sv riscv*_tb.sv
xelab -debug all testbench
xsim testbench -gui -tclbatch run_sim_commands.tcl
```

### Viewing Waveforms
After simulation:
```bash
xsim --view xsim.wdb
# or in Vivado: File → Open → Open Waveform
```

### Cleaning Up
```bash
cd riscv_*/sim
make clean
# or
./clean.sh
```

### Test Program
The test program (`riscvtest.txt`) performs operations and writes results to memory addresses 96 and 100 in hexadecimal format.

---

## References

### Documentation
- See `riscv_single_cycle/README.md` for single-cycle architecture details
- See `riscv_multi_cycle/README.md` for multi-cycle architecture details
- RV32I Instruction Set Documentation - https://docs.riscv.org/reference/isa/unpriv/rv32.html 
- RISC-V Reference Card (SFU CS295 RISC-V Reference Card) - https://www.cs.sfu.ca/~ashriram/Courses/CS295/assets/notebooks/RISCV/RISCV_CARD.pdf
- Digital Design & Computer Architecture: RISC-V Edition or Lecture slides on RISC-V

### Key Files to Study
- **Single-cycle**: Study `riscvsingle_incomplete.sv` template
- **Multi-cycle**: Study existing RTL modules for patterns

---

## FAQ

**Q: My simulation compiles but the testbench fails. How do I debug?**
A:
1. Check the waveform viewer to see what signals are doing (Plot FSM states and track it)
2. Add $display statements to print values
3. Trace through the expected behavior manually
4. Simulate single instruction or a few instructionts to check data flow and control signals

**Q: Can I modify the testbench?**
A: No. The testbench is provided and must work with your implementation.

**Q: What if my simulation times out?**
A: Check that your FSM doesn't have infinite loops. Verify state transitions are correct and you eventually reach FETCH state.