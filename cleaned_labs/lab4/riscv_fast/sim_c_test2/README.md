# RISC-V C Program Simulation (sim_c)

Fast simulation of RISC-V C programs with 4KB BRAM.

## Quick Start

```bash
# Run simulation (requires program.verilog.hex from test1)
make sim

# Clean simulation artifacts
make clean

# Show help
make help
```

## Workflow

1. **Build the C program** in `/test_programs/test1/`:
   ```bash
   cd ../../test_programs/test1
   make
   make copy-to-sim
   ```

2. **Run simulation** in this directory:
   ```bash
   cd ../../riscv_fast/sim_c
   make sim
   ```

3. **Check results** - Look for:
   - `Simulation succeeded` → Test passed ✓
   - `Simulation failed` → Result mismatch ✗
   - `Simulation timeout` → Program stuck in loop

## Debugging with xsim.log

The simulation console output shows the execution trace. Look for:

### Successful Run
```
[CYCLE N] PC=0x... INSTR=0x... WriteBack=...
Write to address 4092 (0x00000ffc) with data 16 (0x00000010)
Memory[4092] = 16 (0x00000010)
Simulation succeeded - C program result correct!
```

### Common Issues

| Symptom | What to Check |
|---------|---------------|
| **Wrong result** | Program output at address 4092 doesn't match expected value |
| **Program stuck** | PC repeats same address (likely infinite loop) |
| **Invalid instructions** | INSTR=0x00000000 or 0xxxxxxxxx (hex file loading issue) |
| **No writes** | MemWrite never goes high (program not executing) |

### Cycle Trace Interpretation

Each cycle shows:
- `PC` - Current program counter
- `STATE` - Processor state (0001=FETCH, 0010=WAIT_INSTR, 0100=EXECUTE, 1000=WAIT_MEM)
- `INSTR` - Current instruction
- `WriteBack` - Register write enable

Example: `PC=0x00002c` at a store instruction means execution is waiting for memory.

## Files

- `program.verilog.hex` - 32-bit word hex file (from test1)
- `disassembly_with_source.txt` - Assembly with C source (from test1)
- `bram_4kb.sv` - 4KB BRAM module
- `riscv_top_c.sv` - Top module
- `riscv_c_tb.sv` - Testbench with pass/fail checker
- `riscv_fast.sv` - Processor core (symlink to ../rtl/)

## Expected Program Behavior

For test1 with `y = func(2, 3)` (2 << 3 = 16):
1. Initialize global variables
2. Call function with shift
3. Write result (16) to address 4092
4. Infinite loop

Simulation stops when the write to 4092 is detected and result is checked.

## Tips

- If hex file is missing: Run `make copy-to-sim` in test_programs/test1/
- If instructions look wrong (0x00000000): Check hex file format is 32-bit width
- Increase timeout in `run_sim_commands.tcl` if program is legitimately slow
- Use `disassembly_with_source.txt` to trace program execution
