# ECE1195 Bonus Lab (120 Points)

## Project Overview

This bonus lab extends the APB GPIO/Timer subsystem from Lab 5 with on-FPGA hardware implementation and advanced PWM peripheral design. 
Students will implement the controller on actual FPGA hardware and design a dedicated PWM peripheral with autonomous timing capabilities.
Both parts of this lab reinforce APB bus design patterns and peripherals used in microcontrollers.

---

## Part I: Vivado FPGA Implementation (50 Points)

Implement the Lab 5 design on the FPGA board with GPIO-connected LEDs and timer-based control logic.

### Part I.a: LED Increment Control (25 Points)

**Objective**: Use the APB Timer to control GPIO LED counting from 0 to 15, incrementing every 0.25 seconds.

**Requirements**:
- Connect GPIO outputs `[3:0]` to four LEDs on the FPGA board (refer to board schematics for pin mappings)
- Write C code that:
  - Initializes the APB Timer with a 0.25-second interval
  - On each timer interrupt, increment GPIO `[3:0]` by 1
  - Wrap counter after reaching 15 (0x0F)
  - Loop continuously with `while(1)`
- The LEDs should display the 4-bit binary count (LED0 = bit 0, LED1 = bit 1, etc.)

**Verification**:
- Power on the FPGA and observe LEDs counting 0→1→2→...→15→0→... with 0.25-second intervals
- Document the observed behavior and timing

### Part I.b: PWM Intensity Control via Timer (25 Points)

**Objective**: Implement PWM (16 intensity levels) using the APB Timer to control LED brightness.

**Requirements**:
- Timer period: **16 ms**
- Step size: **1 ms** (supporting 16 intensity levels: 0%, 6.25%, 12.5%, ..., 93.75%, 100%)
- Implement software PWM where:
  - Timer fires every 1 ms
  - Track elapsed time within each 16 ms period (counter mod 16)
  - For GPIO output bit (e.g., GPIO[0]):
    - If elapsed_time < duty_cycle_level, set bit HIGH
    - Otherwise, set bit LOW
  - Update GPIO at each interrupt
- Cycle through all 16 intensity levels; each level displays for approximately 1 second (16 cycles × 16 ms)
- Write C code to test at least one LED with all intensity levels visible

**Verification**:
- Power on the FPGA and observe one LED fading in brightness from OFF to full brightness, then looping
- Measure or observe the 16 distinct brightness levels
- Document timing and visual verification

---

## Part II: PWM APB Peripheral (70 Points)

Design and implement a dedicated APB PWM peripheral that operates autonomously without CPU intervention after initialization.

### Overview

The PWM peripheral shall:
- Be addressable on the APB bus (separate address range from GPIO/Timer)
- Include control registers to start/stop PWM generation
- Include pulse-width control registers
- Use internal counters/timers to generate PWM output independent of CPU activity
- Support the CPU entering a `while(1)` loop while PWM continues

### Register Map

Define an appropriate register map for the PWM peripheral (suggestion: use 256-byte slot stride, following Lab 5 APB conventions):

| Address (offset +base) | Register Name | R/W | Description |
|---|---|---|---|
| 0x00 | CONTROL | RW | Bit[0]: PWM enable; bit[1]: PWM active status |
| 0x04 | PERIOD | RW | PWM period in timer ticks (e.g., 16000 ticks = 16 ms @ 1 MHz) |
| 0x08 | DUTY_CYCLE | RW | PWM duty cycle in ticks (0 to PERIOD); controls pulse width |
| 0x0C | STATUS | R | PWM operation status; mirrors CONTROL[1] |

*(You may modify this map based on your design; document your chosen map in the RTL.)*

### Implementation Requirements (70 Points)

#### a) APB Peripheral Integration (15 Points)
- Add PWM peripheral to `apb_top.sv` (or equivalent APB decoder)
- Decode PWM address range on the APB bus
- Implement APB slave handshake (`pready`, `psel`, `penable`, `paddr`, `pwrite`, `pwdata`)
- Correctly multiplex PWM read data onto APB output bus

#### b) PWM Control Logic (25 Points)
- Implement control register (`CONTROL`):
  - Bit[0]: Enable signal; when set, PWM counter begins counting
  - Bit[1]: Active status flag; set when counter is actively counting
- Implement `PERIOD` register:
  - Stores the total PWM period in clock cycles
  - Updatable only when PWM is disabled (or add synchronization logic)
- Implement `DUTY_CYCLE` register:
  - Stores pulse width in clock cycles
  - Valid range: 0 to `PERIOD`
  - Updatable at any time (user responsibility to avoid glitches)
- Implement internal `COUNTER`:
  - Counts from 0 to `PERIOD-1` on every clock
  - Resets to 0 when reaching `PERIOD`
  - Only active when `CONTROL[0]` = 1 (enabled)

#### c) PWM Output Generation (20 Points)
- Implement PWM output signal:
  - Output is HIGH when `COUNTER < DUTY_CYCLE`
  - Output is LOW when `COUNTER >= DUTY_CYCLE`
  - Output reflects current counter and duty cycle values in real-time
- Optionally, OR PWM output with GPIO output:
  - Route PWM output through a gate: `GPIO_OUT[0] = GPIO[0] | PWM_OUT` (or choose a different GPIO bit)
  - Set GPIO[0] LOW (0x0) to isolate PWM output on the bus for verification
- Test PWM output:
  - Program `PERIOD` and `DUTY_CYCLE` registers
  - Assert `CONTROL[0]` (enable PWM)
  - Verify duty cycle: LED brightness change

#### d) Autonomous Operation and CPU Independence (10 Points)
- Verify that PWM continues to generate output while CPU executes `while(1)` loop
- No interrupt-driven polling required from CPU; PWM operates standalone
- Test it:
  - CPU code example: Initialize PWM → enter infinite loop
  - Observe: LED retains set brightness whe CPU is in idle loop

### Verification Checklist

- [ ] PWM peripheral is addressable via APB reads/writes
- [ ] Control register correctly enables/disables PWM counter
- [ ] PWM counter increments from 0 to (PERIOD-1), then resets
- [ ] PWM output signal toggles with correct frequency = clock_freq / PERIOD
- [ ] PWM duty cycle matches register programming: HIGH_TIME / PERIOD
- [ ] PWM continues running while CPU executes `while(1)` loop
- [ ] Valid register values (0 ≤ DUTY_CYCLE ≤ PERIOD) produce correct output

---

## Implementation Notes

### Vivado Flow (Part I)

For Vivado FPGA implementation guidance, refer to previous ECE1195 labs (Lab 1, Lab 2, etc.). The process involves:
- Constraint files (`.xdc`) for I/O pin mapping
- Build flow via synthesis, place & route
- Bitstream generation and FPGA programming

### RTL Development (Part I & II)

- Extend `riscv_fast/rtl/apb_top.sv` to add PWM peripheral decode and address multiplexing and OR GPIO out signals to PWM output.
- Create `riscv_fast/rtl/apb_pwm.sv` for PWM peripheral logic (similar structure to `apb_timer.sv`)
- Use 256-byte address slots to avoid conflicts with Timer (0x00_xx00) and GPIO (0x01_xx00) ranges

### C Code Development

- Leverage existing `apb_gpio.h` header style for PWM register definitions
- Create test programs in `test_programs/apb_pwm_test/` or similar
- Include startup code and linker script (copy from existing test programs)
- Compile and load `.hex` files into BRAM simulation or FPGA bitstream

### Simulation-First Approach (Recommended)

- Verify PWM logic in `riscv_fast/sim_apb/` testbench before FPGA deployment (NOTE: use a smaller period, 10-100 cycles, to testin simualtion)
- Update testbench to include PWM register accesses and output observations if needed
- Compare PWM waveform captured in `wave.wdb` against expected behavior

---

## Grading Rubric

| Part | Category | Points | Criteria |
|---|---|---|---|
| **I.a** | LED Increment | 25 | LEDs count 0→15 incrementing every 0.25s; timer interrupt handling; clean C code; documented verification |
| **I.b** | PWM Brightness | 25 | 16 intensity levels visible; 16ms period with 1ms steps; smooth fading; all levels demonstrated; documented timing |
| **II.a** | APB Integration | 15 | PWM addressable on APB; correct handshake; address decoding; bus multiplexing functional |
| **II.b** | Control Logic | 25 | CONTROL/PERIOD/DUTY_CYCLE registers work correctly; counter increments properly; enable logic functional |
| **II.c** | PWM Output | 20 | Output toggles with correct frequency; duty cycle accurate; matches register settings; edge cases (0%/100%) handled |
| **II.d** | Autonomous Op. | 10 | PWM continues while CPU in while(1) loop; CPU-independent verification documented |
| **Total** | | **120** | Full implementation and verification |

---

## Deliverables

1. **C Code**: Test programs for Part I.a, Part I.b, and Part II (PWM initialization + verification loop)
2. **RTL Code**: 
   - Modified `apb_top.sv` (or equivalent) with PWM address decode
   - New `apb_pwm.sv` (or included in top-level) with PWM logic
3. **Testbench** (optional but recommended):
   - Updated `riscv_apb_tb.sv` with PWM peripheral tests
   - Screenshot/log of PWM signals in waveform viewer
4. **FPGA Bitstream** (Part I only):
   - `.bit` file for FPGA programming (if on-board testing completed)
5. **Documentation**:
   - Lab notebook or summary explaining:
     - Part I.a: Observed LED timing and behavior
     - Part I.b: Demonstrated 16 intensity levels with timing measurements
     - Part II: Register map, control flow, verification method, and observed PWM output (oscilloscope capture optional but encouraged)
   - Register map diagram (hand-drawn or digital)
   - Any design trade-offs or challenges encountered

---

## Summary

This bonus lab combines embedded software (C code + APB programming) with RTL design (PWM peripheral) and hardware implementation (FPGA board). Success requires:
- **Part I**: Understanding timer-based software PWM and FPGA I/O constraints
- **Part II**: Designing a self-contained APB slave that operates independently of the CPU

