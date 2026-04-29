# RISC-V Single Cycle Processor Simulation

This folder contains the RISC-V single-cycle processor design and simulation scripts organized by functionality.

## Directory Structure

```
riscv_single_cycle/
├── rtl/                        # Register Transfer Level (HDL design)
│   └── riscvsingle.sv          # RISC-V processor design
├── sim/                        # Simulation files and scripts
│   ├── riscvsingle_tb.sv       # Testbench
│   ├── riscvtest.txt           # Test program (machine code)
│   ├── run_simulation.sh       # Main simulation script
│   ├── run_sim_commands.tcl    # xsim simulation commands
│   ├── run_gui.tcl             # Interactive GUI mode
│   ├── clean.sh                # Clean simulation output
│   ├── Makefile                # Build automation
│   └── [simulation output files generated here]
└── README.md
```

## Files

**RTL Design:**
- **rtl/riscvsingle.sv** - Complete RISC-V single-cycle processor implementation

**Simulation:**
- **sim/riscvsingle_tb.sv** - Testbench that verifies the design
- **sim/riscvtest.txt** - Test instruction program (machine code)
- **sim/run_simulation.sh** - Main bash script to run simulation (Git Bash compatible)
- **sim/run_sim_commands.tcl** - xsim TCL commands for non-GUI mode
- **sim/run_gui.tcl** - xsim TCL commands for interactive GUI mode
- **sim/clean.sh** - Bash script to clean simulation output files
- **sim/Makefile** - Build automation (optional, for environments with make)

## How to Run the Simulation

### Option 1: Bash Script (Recommended - Git Bash)
Navigate to the `sim` directory and run:
```bash
cd sim
./run_simulation.sh
```

This will:
1. Compile the RTL files from `../rtl/`
2. Compile the testbench
3. Elaborate the design
4. Run the simulation for 500 ns
5. Generate waveform file: `wave.wdb` (xsim native format)
6. Display test results

**Expected Output:**
```
Memory[100] =         25 (0x00000019)
Simulation succeeded
```

### Option 2: Clean Simulation Output
From the `sim` directory, remove all simulation-generated files:
```bash
cd sim
bash clean.sh
```

Or with make (if available):
```bash
cd sim
make clean
```

### Option 3: Using Makefile (if make is available)
```bash
cd sim
make sim      # Run simulation
make clean    # Clean output
make help     # Show targets
```

### Option 4: Manual xsim Commands
In Vivado Design Suite command line or tcl shell:
```bash
cd sim
xvlog -sv ../rtl/riscvsingle.sv riscvsingle_tb.sv
xelab -debug all testbench
xsim testbench -tclbatch run_sim_commands.tcl
```

### Option 5: Interactive GUI Mode
```bash
cd sim
xvlog -sv ../rtl/riscvsingle.sv riscvsingle_tb.sv
xelab -debug all testbench
xsim testbench -gui -tclbatch run_gui.tcl
```

This opens the xsim GUI where you can interactively control the simulation and view waveforms.

## Simulation Details

### Test Program
The test program (riscvtest.txt) performs the following operations:
- Arithmetic operations (add, sub, and, or, slt)
- Immediate arithmetic (addi, andi, ori, slti)
- Memory operations (lw, sw)
- Conditional branching (beq)
- Unconditional jumps (jal)

**Success Condition**: The simulation succeeds when the value 25 (0x19) is written to address 100 (0x64). When this happens, the testbench displays "Simulation succeeded" and stops.

### Simulation Parameters
- **Clock Period**: 10 ns (100 MHz equivalent)
- **Simulation Time**: 500 ns (sufficient for ~50 instruction cycles)
- **Number of Instructions**: 21 (plus infinite loop at end)
- **Processor Type**: Single-cycle (1 instruction per clock cycle)

### Expected Output
When successful, you should see in the simulation console:
```
Simulation succeeded
```

## Viewing Waveforms

The simulation generates xsim native waveform files in the `xsim.dir/work.testbench` folder.

**To view waveforms in Vivado:**
1. Run the simulation: `./run_simulation.sh`
2. Once complete, waveforms are captured in xsim's native database
3. Open Vivado and go to File → Open → Open Waveform
4. Navigate to `xsim.dir/work.testbench` and select the waveform database
5. The waveform viewer will load with all logged signals

Alternatively, you can use the xsim GUI with `xsim testbench -gui` for interactive waveform viewing.

## Notes

- Register x0 is hardwired to 0
- Memory is little-endian
- Word-aligned memory access only