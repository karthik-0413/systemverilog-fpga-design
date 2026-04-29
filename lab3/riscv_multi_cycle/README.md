# RISC-V Multi-Cycle Processor

A multi-cycle implementation of a RISC-V (RV32I) processor based on Digital Design & Computer Architecture: RISC-V Edition.

## Directory Structure

```
riscv_multi_cycle_compact/
├── rtl/
│   └── riscvmulti.sv          # RTL design (top, controller, datapath, ALU, etc.)
├── sim/
│   ├── riscvmulti_tb.sv       # Testbench module
│   ├── run_simulation.tcl     # Vivado xsim batch simulation script
│   ├── run_simulation.sh      # Shell script (Linux/Mac/WSL)
│   ├── run_sim_commands.tcl   # xsim commands (logging, timing)
│   ├── run_gui.tcl            # xsim GUI simulation script
│   ├── clean.sh               # Cleanup script
│   ├── Makefile               # Makefile for easy commands
│   └── riscvtest.txt          # Test program memory image
└── README.md                  # This file
```

## Instructions To Be Implemented

### R-Type
- `add` - Add
- `sub` - Subtract
- `and` - Bitwise AND
- `or`  - Bitwise OR
- `slt` - Set on Less Than

### I-Type ALU
- `addi` - Add Immediate
- `andi` - AND Immediate
- `ori`  - OR Immediate
- `slti` - Set on Less Than Immediate

### Memory
- `lw` - Load Word
- `sw` - Store Word

### Branch/Jump
- `beq` - Branch if Equal
- `jal` - Jump and Link



## Simulation

### Running Simulations

#### Method 1: Vivado TCL Script (Batch Mode)
```bash
cd sim
vivado -mode batch -source run_simulation.tcl
```

#### Method 2: Vivado TCL Script (Interactive GUI)
```bash
cd sim
vivado -mode gui
# In Vivado, run: source run_simulation.tcl
```

#### Method 3: Manual xsim
```bash
cd sim
xvlog -sv ../rtl/riscvmulti.sv riscvmulti_tb.sv
xelab -debug all testbench
xsim testbench -gui -tclbatch run_sim_commands.tcl
```

#### Method 4: Shell Script (Linux/Mac/WSL)
```bash
cd sim
chmod +x run_simulation.sh
./run_simulation.sh
```

### Simulation Parameters

- **Clock Period**: 10 ns (5 ns high, 5 ns low)
- **Simulation Duration**: 2000 ns (adjustable in `run_sim_commands.tcl`)
- **Test Case**: Write value 25 (0x19) to memory address 100 (0x64)

### Expected Output

```
Memory[100] = 25 (0x00000019)
Simulation succeeded
```

## Design Hierarchy

```
top
├── riscvmulti
├── mem (Memory module)
```

## Key Differences from Single-Cycle

1. **Multi-cycle execution**: Each instruction takes multiple clock cycles
2. **State machine control**: Control flow using FSM
3. **Intermediate storage**: Registers store values between stages
4. **Longer simulation time**: More cycles needed for same instructions
5. **Higher clock frequency capable**: Can run at higher clock frequencies

## Memory File

The simulation loads a memory file `riscvtest.txt` which contains the test program. This file should be in the `sim/` directory or the working directory when running the simulation.

## Waveform Analysis

After simulation, you can view the generated waveform database (`xsim.wdb`) using:
```bash
xsim --view xsim.wdb
```

Or open it in Vivado with the Wave Analyzer tool.

## Cleaning Simulation Files

To clean up generated simulation files (logs, databases, temporary files):

**Using shell script:**
```bash
cd sim
chmod +x clean.sh
./clean.sh
```

**Using Makefile:**
```bash
cd sim
make clean
```

**Manual cleanup:**
```bash
cd sim
rm -rf xsim.dir .Xil *.log *.jou
rm -f xsim.wdb xsim.wcfg work.testbench.wdb *.pb
```

## Debugging Tips

- Use `log_wave [get_objects -r *]` in TCL to capture all signals
- Increase simulation duration if test doesn't complete
- Check `riscvtest.txt` is in the correct location
- Monitor state transitions in `mainfsm` to debug control flow
- Check ALU output and result mux to debug data flow

## References

- Digital Design & Computer Architecture: RISC-V Edition
- RISC-V Instruction Set Manual, Vol. I: User-Level ISA v2.2

## Notes

- Register x0 is hardwired to 0
- Memory is little-endian
- Word-aligned memory access only
