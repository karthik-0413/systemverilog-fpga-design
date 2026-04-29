# Test1 - RISC-V C Program Test

This directory contains a simple C program that tests the RISC-V processor with basic arithmetic and memory operations.

## Program Overview

The test1 program:
1. Initializes two global variables: `f = 2`, `g = 3`
2. Calls a function that performs a left shift: `y = func(f, g)` → `y = 2 << 3 = 16`
3. Writes the result to the top of 4KB BRAM at address 4092 (byte address)
4. Enters an infinite loop

## Building the Program

```bash
cd /ihome/pmohan/pr3/projects/ece1195_test/lab4/test_programs/test1
make
```

This will:
- Compile the C code
- Generate disassembly with source code
- Generate hex files with proper 32-bit word width
- Display BRAM usage statistics

## Running the Simulation

After building, copy the hex file and disassembly to the sim_c folder and run simulation:

```bash
make copy-to-sim
```

This command:
- Copies `program.verilog.hex` to `../../riscv_fast/sim_c/`
- Copies `disassembly_with_source.txt` to `../../riscv_fast/sim_c/`

Then run the simulation:

```bash
cd ../../riscv_fast/sim_c
make sim
```

## Expected Results

The simulation should output:
```
Memory[4092] = 16 (0x00000010)
Simulation succeeded - C program result correct!
```

If the result is different, check:
- The shift amount in `src/main.c` (currently: `y = func(f, g)` with `g = 3`)
- Update the expected value in the testbench if you change the program

## Available Make Targets

| Target | Description |
|--------|-------------|
| `all` | Build everything (default) |
| `disassembly` | Generate assembly code with source |
| `hex` | Generate hex files (Intel, Verilog with 32-bit width) |
| `sections` | Analyze ELF sections and memory map |
| `size` | Show program size and BRAM usage |
| `copy-to-sim` | Copy hex and disassembly to sim_c folder |
| `clean` | Remove build artifacts |
| `rebuild` | Clean and build everything |

## File Descriptions

- `src/main.c` - Main C program with function and memory write
- `startup.S` - Startup code (BSS initialization, stack setup)
- `linker.ld` - Linker script (4KB BRAM layout)
- `Makefile` - Build configuration

## Output Files

After building, outputs are in the `outputs/` directory:
- `program.elf` - Compiled executable
- `program.hex` - Intel hex format
- `program.verilog.hex` - SystemVerilog hex format (32-bit width)
- `disassembly.txt` - Assembly without source
- `disassembly_with_source.txt` - Assembly with C source code
- `sections.txt` - ELF section analysis
