# Lab 5: RV32I with APB GPIO and Timer Peripherals

## Project Overview

This lab extends a RV32I RISC-V multi-cycle processor with a bus-based peripheral subsystem. You will implement an APB (ARM APB) finite state machine and a timer peripheral, then verify their behavior through simulation.

**Key Components:**
- **RV32I Core** (`riscv_fast.sv`): Single-cycle processor with basic instruction set.
- **BRAM** (`bram_4kb.sv`): 4 KB program memory.
- **APB Bridge** (`mem_to_apb_bridge.sv`): Converts CPU memory requests to APB transactions.
- **GPIO Peripheral** (`apb_gpio.sv`): 8-bit GPIO with input/output registers (COMPLETE).
- **Timer Peripheral** (`apb_timer.sv`): Configurable counter with limit and control registers.
- **APB Top** (`apb_top.sv`): Address decode and peripheral muxing.
- **Top Module** (`riscv_top.sv`): Integrates core, BRAM, and APB subsystem.

## File Organization

```
riscv_fast/
├── rtl/                   # Synthesis RTL
│   ├── riscv_fast.sv      # RV32I core
│   ├── riscv_top.sv       # Top-level with APB integration
│   ├── mem_to_apb_bridge.sv   # APB FSM (Part 1)
│   ├── apb_gpio.sv        # GPIO peripheral (complete)
│   ├── apb_timer.sv       # Timer peripheral (Part 2)
│   └── apb_top.sv         # APB wrapper and decode
├── sim_apb/               # APB simulation harness
│   ├── run_waveform.sh    # Waveform capture launcher
│   ├── riscv_apb_tb.sv    # Testbench (compare against REFERENCE_xsim.log)
│   └── program.verilog.hex # Load from test_programs/apb_gpio_toggle/outputs
└── sim_c/                   # Non-APB simulation (reference only)
test_programs/
├── apb_gpio_toggle/       # Full program with GPIO and timer tests
│   ├── src/main.c         # Test program (timer tests commented out)
│   ├── include/apb.h      # APB register definitions
│   └── Makefile           # Build program to BRAM hex image
└── test1/                 # Reference baseline program

REFERENCE_xsim.log         # Expected simulation output (trace this!)
AGENTS.md                  # Project layout guide
```

## Register Memory Map

Both GPIO and Timer use 256-byte address slots starting at `0x0004_0000`.

### GPIO0 @ 0x0004_0000 (256-byte slot 0)
- `0x00`: `gpio_in` (read-only) — sample external input pins
- `0x04`: `gpio_out` (read/write) — drive external output pins

### Timer @ 0x0004_0100 (256-byte slot 1)
- `0x00`: reserved
- `0x04`: `counter` (read/write) — current counter value
- `0x08`: `limit` (read/write) — limit value; counter stops when reached
- `0x0C`: `control` (write-only) — commands: bit[0]=RESET, bit[1]=ENABLE
- `0x10`: `status` (read-only) — bit[0]=running, bit[1]=done

## Simulation

Run the APB test:
```bash
cd riscv_fast/sim_apb
make clean
module load FPGA/Vivado/2025.1
bash run_waveform.sh
```

Compare console output against `REFERENCE_xsim.log` to verify correctness.

---

## Part 1: APB FSM Implementation (50 points)

### Task

Implement the two-phase APB state machine in `mem_to_apb_bridge.sv` (in `riscv_fast/rtl/`).

**Reference:** Lines 55–110 contain the structure and edge descriptions. Complete the missing sequential and combinational logic for the FSM state transitions and APB signal control. The comments already outline:
- **IDLE_SETUP**: Accept CPU request, capture address/data, assert `busy`.
- **ACCESS**: Hold APB signals stable, pulse `resp_valid` when `pready` asserts.

### Verification

1. Build the program:
   ```bash
   cd test_programs/apb_gpio_toggle && make clean && make all
   ```

2. Run the APB simulation and check GPIO state transitions (should print "GPIO0 out changed" lines).

3. Confirm GPIO0 performs the initial write (`0x07`), then loopback (`0x5A → 0xA5`).

4. **Pass criterion**: Simulation ends cleanly with message about GPIO0 output matching input.

---

## Part 2: Timer Control Logic (50 points)

### Task

Implement the timer counter and control state machine in `apb_timer.sv` (in `riscv_fast/rtl/`).

**Reference:** Lines 108–170 contain the state logic placeholder. Complete the timer behavior:
- **RESET command** (bit[0]): Clear counter, status, and control registers.
- **ENABLE command** (bit[1]): Set `running=1`, `done=0`.
- **Running state**: Increment counter each cycle; when `next_count ≥ limit`, stop and update status register bits.

The comments in the file provide hints (incomplete) for implementation. You can use it or ignore it.

### Verification

1. Uncomment the timer test code in `test_programs/apb_gpio_toggle/src/main.c` (around line 13–30).
   - The program will set `TIMER_LIMIT = 8`, reset, enable, poll `TIMER_STATUS_DONE`.
   - Then repeat with `TIMER_LIMIT = 16`.

2. Rebuild and run:
   ```bash
   cd test_programs/apb_gpio_toggle && make clean && make all
   cp outputs/program.verilog.hex ../../riscv_fast/sim_apb/
   cd ../../riscv_fast/sim_apb
   bash run_waveform.sh
   ```

3. Compare the output against `REFERENCE_xsim.log`:
   - Look for "TIMER count=X status=..." messages showing the counter increments.
   - Verify two runs: first to count=8, second to count=16.
   - Confirm final GPIO0 output is `0xA5` and end marker `0xC0FFEE` is written.

4. **Pass criterion**: All TIMER state transitions and GPIO loopback match the reference log.

---

## Grading

- **Part 1 (50 pts)**: APB FSM correctly routes requests through SETUP → ACCESS, drives GPIO state changes.
- **Part 2 (50 pts)**: Timer counter increments, limit comparison stops timer, control commands work, and final GPIO loopback succeeds.
- **Total: 100 pts**

## Notes

- The GPIO peripheral is already complete; focus on the two state machines.
- Do not modify the CPU core, BRAM, or testbench logic.
- Use the comments in the RTL as your design specification.
- The simulation will print detailed APB and timer trace output; use it to debug state transitions.
