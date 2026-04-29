# Lab 4 Part 2 — PYNQ BRAM Overlay & RISC-V on FPGA

## Table of Contents
1. [Design Overview](#1-design-overview)
2. [Building the Vivado Project](#2-building-the-vivado-project)
3. [Deploying the Overlay](#3-deploying-the-overlay)
4. [Running the Notebook on PYNQ](#4-running-the-notebook-on-pynq)
5. [FSM vs RISC-V — The Reset-to-Run Paradigm](#5-fsm-vs-risc-v--the-reset-to-run-paradigm)
6. [Student Assignment — RISC-V Wrapper](#6-student-assignment--risc-v-wrapper)

---

## 1. Design Overview

### Block Diagram

```
       ┌────────────────────────────────────────────────────┐
       │                  Zynq PS (ARM)                     │
       │   M_AXI_GP0 ──────────────────────────────────     │
       └──────┬────────────────────────────────────────┬───┘
              │ AXI4                                   │ AXI4
      ┌───────▼───────┐                       ┌────────▼──────┐
      │ axi_bram_ctrl │                       │  axi_gpio_0   │
      │  (Port A)     │                       │  ch1: reset   │
      └───────┬───────┘                       │  ch2: done    │
              │ BRAM_PORTA                    └──┬─────────┬──┘
              │                     gpio_io_o ──┘         │ gpio2_io_i
              │                        (reset)             │ (done)
      ┌───────▼──────────────────────────┐                │
      │         blk_mem_gen_0            │                │
      │      4KB True Dual-Port BRAM     │                │
      │   Port A ◄── AXI BRAM ctrl      │                │
      │   Port B ◄────────────────────► bram_wrapper_0   │
      └──────────────────────────────────┘   │           │
                                             │ (BRAM_PORTB│ standard interface)
                                      ┌──────┴────────────┴───┐
                                      │    bram_wrapper_0      │
                                      │  bram_test_fsm (RTL)  │
                                      │  reset → run → DONE   │
                                      └───────────────────────┘
```

### Key Components

| IP / Module | Role |
|---|---|
| `processing_system7_0` | Zynq PS — runs Python/PYNQ notebook |
| `blk_mem_gen_0` | 4 KB True Dual-Port BRAM (1024 × 32-bit) |
| `axi_bram_ctrl_0` | AXI4 access to BRAM Port A from Python |
| `axi_gpio_0` | Dual-channel GPIO: ch1=reset (out), ch2=done (in) |
| `bram_wrapper_0` | Custom RTL wrapping the FSM, connects to Port B |
| `bram_test_fsm` | FSM: reads words 0–3, sums, writes to word 1023 |

### BRAM Port Assignment

| Port | Connected To | Access Style |
|---|---|---|
| Port A | AXI BRAM Controller | Byte-addressed via AXI (Python) |
| Port B | `bram_wrapper_0` (FSM) | Byte-addressed, 32-bit words, native BRAM interface |

### GPIO Mapping

| Channel | Direction | Signal | Description |
|---|---|---|---|
| ch1 (`gpio_io_o`) | PS → RTL | `reset` | Active-high. Assert to hold FSM in IDLE. Deassert to start run. |
| ch2 (`gpio2_io_i`) | RTL → PS | `done` | 1 when FSM has completed and is stuck in DONE state. |

### FSM Operation

The FSM reads **byte addresses** 0, 4, 8, 12 (words 0–3), computes their 32-bit sum, and writes the result to **byte address 4092** (word 1023, top of 4 KB BRAM). It then sticks in the `DONE` state until reset is reasserted.

---

## 2. Building the Vivado Project

### Prerequisites

- Vivado 2022.x installed and on `$PATH`
- PYNQ-Z1 board files installed
- Working directory: `vivado_bram_sample/`

### Option A — Batch Mode (automated, Run Option B 1st to understand the process)

Delete any previous build first, then run the script:

```bash
cd vivado_bram_sample
rm -rf bram_test bram_test.* bram_test.cache bram_test.gen bram_test.hw \
       bram_test.ip_user_files bram_test.runs bram_test.sim bram_test.srcs

vivado -mode batch -source scripts/create_project.tcl
```

This script will:
1. Create the Vivado project
2. Build the block design (PS + BRAM + GPIO + FSM wrapper)
3. Run synthesis and implementation
4. Generate the bitstream
5. Export `export/bram_test_overlay.xsa`

Expected output ends with:
```
Done creating BRAM test overlay
Overlay file: .../export/bram_test_overlay.xsa
```

### Option B — Interactive Mode (step-by-step, RECOMMENDED first time)

Open Vivado GUI and paste each section of `scripts/create_project_interactive.tcl` into the Tcl Console one block at a time. Each block prints a `=== STEP N ===` banner confirming progress. This lets you inspect the block diagram between steps.

Key steps in the interactive script:

| Step | Action |
|---|---|
| 1–5 | Create project, add RTL sources, create block design, add PS7 |
| 6 | Add Block Memory Generator (4 KB, True Dual-Port) |
| 7 | Add AXI BRAM Controller (Port A only) |
| 8 | Add AXI GPIO (ch1 output reset, ch2 input done) |
| 9 | Add `bram_wrapper_0` custom RTL module |
| 10 | Connect Port A (AXI BRAM ctrl ↔ BRAM) |
| 11 | Connect Port B (`bram_wrapper_0` ↔ BRAM via standard BRAM interface) |
| 12 | Connect GPIO: `gpio_io_o` → `reset`, `done` → `gpio2_io_i` |
| 13 | Connect clocks and AXI reset |
| 14 | AXI SmartConnect automation |
| 15 | Address assignment |
| 16 | Validate and save block design |
| 17–20 | Synthesis, implementation, bitstream, XSA export |

---

## 3. Deploying the Overlay

After the build completes, extract the bitstream and hardware handoff file:

```bash
cd vivado_bram_sample/export
./deploy.sh
```

This script:
1. Removes any previous `bram_test_overlay/` extract directory
2. Unzips `bram_test_overlay.xsa` into `bram_test_overlay/`
3. Copies `bram_test_overlay.bit` → `lab4.bit`
4. Copies `design_1.hwh` → `lab4.hwh`

Expected output:
```
Done:
-rw-r--r-- lab4.bit  3.9M
-rw-r--r-- lab4.hwh  198K
```

### Copy to PYNQ

Transfer the overlay files and notebook to the PYNQ board over SCP (or USB drive / Jupyter file upload):

```bash
# Replace 192.168.2.99 with your PYNQ board's IP
scp export/lab4.bit export/lab4.hwh xilinx@192.168.2.99:/home/xilinx/overlays/
scp test/test_bram_overlay.ipynb xilinx@192.168.2.99:/home/xilinx/jupyter_notebooks/
```
This is a sample path. Change based on your setup.
Default PYNQ credentials: user `xilinx`, password `xilinx`.

---

## 4. Running the Notebook on PYNQ

Open a browser, navigate to `http://<PYNQ-IP>:9090`, and open `test_bram_overlay.ipynb`.

### Cell-by-cell summary

**Cell 1 — Load overlay**
```python
overlay = Overlay('/home/xilinx/overlays/lab4.bit')
bram_ctrl = overlay.axi_bram_ctrl_0   # Memory object (byte-addressed)
gpio      = overlay.axi_gpio_0        # AxiGPIO object
```

**Cell 2 — Helper functions**
```python
is_fsm_done()          # read done bit from GPIO ch2
fsm_reset(True/False)  # assert/deassert reset via GPIO ch1
run_fsm()              # assert reset → deassert → wait for done=1
write_bram_word(addr, data)   # word-indexed write (multiplied by 4 internally)
read_bram_word(addr)          # word-indexed read
```

**Test 1 — Direct BRAM access**
Writes `0xDEADBEEF` to an arbitrary address and reads it back to confirm AXI access works.

**Test 2 — FSM operation**
1. Write known values to words 0–3
2. Hold FSM in reset (`fsm_reset(True)`)
3. Call `run_fsm()` — deasserts reset, waits for `done=1`
4. Read word 1023 and verify it equals `sum(words 0–3)`
5. Confirm FSM stays in `DONE` state (done remains 1 until reset)

### GPIO Control API

```python
gpio.channel1.write(1, 0x1)   # assert reset   → FSM holds at IDLE
gpio.channel1.write(0, 0x1)   # deassert reset → FSM runs to DONE
gpio.channel2.read()           # returns 1 when FSM in DONE state
```

---

## 5. FSM vs RISC-V — The Reset-to-Run Pattern

### How they are the same

The `bram_test_fsm` and a RISC-V CPU share the same fundamental execution model:

| Concept | `bram_test_fsm` | RISC-V CPU |
|---|---|---|
| **Reset** | Active-high `reset` holds FSM in `IDLE` | Active-high `reset` holds PC at 0 |
| **Start** | Deassert `reset` → FSM auto-runs | Deassert `reset` → CPU fetches from PC=0 |
| **Execution** | Advances through fixed states | Advances through instructions |
| **Halt** | Sticks in `DONE` state forever | Sticks in `while(1)` (infinite loop) |
| **Result** | Written to BRAM word 1023 | Written to BRAM byte address 4092 by the C program |
| **Observation** | Python reads BRAM word 1023 via AXI | Python reads BRAM word 1023 via AXI |

### Reset-to-run sequence (both designs)

```
Python:  assert reset=1  ──►  RTL sits idle, PC/state frozen
Python:  write data to BRAM  (or load program)
Python:  deassert reset=0  ──►  RTL starts executing
RTL:     runs to completion / while(1)
Python:  poll done / wait fixed time
Python:  read result from BRAM via AXI
```

### Key difference: memory role

- **FSM**: BRAM is *data memory only*. The FSM logic is hardwired in RTL states.
- **RISC-V**: BRAM is *both instruction and data memory*. The program (`.text`) is loaded before reset deassert; data (`.sbss`, stack) lives in the same BRAM.

---

## 6. Student Assignment — RISC-V Wrapper

Your task is to replace `bram_wrapper_0` with a `riscv_wrapper` that wraps your RISC-V CPU and connects it to the same BRAM Port B. Python will load the compiled program into BRAM, then trigger execution via the same GPIO reset/done interface.

### Step 1 — Create `riscv_wrapper.v`

Model it after `bram_wrapper.v`. The wrapper must:
- Accept `clk` and `reset` (active-high, from GPIO ch1)
- Connect your CPU's instruction/data memory port to `BRAM_PORTB` via the standard Xilinx BRAM interface (`X_INTERFACE_INFO`)
- Make sure to handle remaining singals in RSIC-V top level wrapper (busy etc.)

Skeleton:

```verilog
module riscv_wrapper(
    input  wire         clk,
    input  wire         reset,   // Active-high, from GPIO ch1

    // Standard Xilinx BRAM interface — Vivado auto-connects to blk_mem_gen Port B
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_SIZE 4096, MEM_WIDTH 32,
                                 MEM_ECC NONE, READ_WRITE_MODE READ_WRITE, READ_LATENCY 1" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK"  *) output wire        bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN"   *) output wire        bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE"   *) output wire [3:0]  bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *) output wire [31:0] bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN"  *) output wire [31:0] bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *) input  wire [31:0] bram_dout,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST"  *) output wire        bram_rst,
    
);
    // Instantiate your RISC-V CPU here
    // Connect CPU memory interface to bram_* ports
    // ...

    assign bram_clk = clk;
    assign bram_rst = 1'b0;
    assign bram_en  = 1'b1;
endmodule
```

**Step 1b — Generating `done`**

The RISC-V CPU has no explicit "done" output. You can monitor the program execution by looking at BRAM value:

- **Memory Polling**: The C program already writes result to address 4092. Python can simply poll that address instead of using `done` — set `done = 1'b0` and poll with a timeout.

### Step 2 — Update `create_project.tcl`

Replace `bram_wrapper` with `riscv_wrapper` in the block design script:

```tcl
# Replace bram_wrapper with riscv_wrapper
create_bd_cell -type module -reference riscv_wrapper riscv_wrapper_0

# Connect Port B
connect_bd_intf_net [get_bd_intf_pins riscv_wrapper_0/BRAM_PORTB] \
                    [get_bd_intf_pins blk_mem_gen_0/BRAM_PORTB]

# GPIO: ch1 → reset
connect_bd_net [get_bd_pins axi_gpio_0/gpio_io_o]  [get_bd_pins riscv_wrapper_0/reset]

# Clock
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins riscv_wrapper_0/clk]
```

### Step 3 — Build the program

On the Linux server (where the RISC-V toolchain is installed):

```bash
cd lab4_part2/test_programs/test1
make
```

Outputs of interest:

| File | Description |
|---|---|
| `outputs/program.verilog.hex` | Verilog-format hex, 32-bit words, load into BRAM |
| `outputs/disassembly_with_source.txt` | Annotated disassembly (find `while(1)` PC here) |
| `outputs/sections.txt` | ELF section map (check `.text` fits within 4 KB) |

### Step 4 — Load program into BRAM from Python

Add a cell to your PYNQ notebook that loads `program.verilog.hex` into BRAM via the AXI BRAM Controller **before** releasing CPU reset:

```python
def load_hex(bram, hex_path):
    """Load a Verilog hex file (--verilog-data-width=4) into BRAM."""
    byte_addr = 0
    with open(hex_path, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('@'):
                # Address in the hex file is a word address; convert to byte address
                byte_addr = int(line[1:], 16) * 4
            else:
                for word_str in line.split():
                    bram.write(byte_addr, int(word_str, 16))
                    byte_addr += 4

load_hex(bram_ctrl, 'program.verilog.hex')
print("Program loaded into BRAM")
```

> **Note**: The `--verilog-data-width=4` flag in the Makefile produces 32-bit (4-byte) words per line. The `@` address markers are word-indexed, so multiply by 4 to get the byte address used by the AXI BRAM Controller.

### Step 5 — Run the RISC-V CPU

```python
# Hold CPU in reset while loading program (already done above, but be explicit)
fsm_reset(True)      # reuse the same helper — ch1 controls reset
time.sleep(0.01)

# Release reset → CPU starts fetching from PC=0
fsm_reset(False)

# Wait for completion (check BRAM or fixed timeout)
timeout = 1.0  # seconds
t0 = time.time()
while not is_fsm_done():
    if time.time() - t0 > timeout:
        print("Timeout — CPU may still be running or polling failed")
        break
    time.sleep(0.001)

# Read result from top of BRAM (byte address 4092 = word 1023)
result = read_bram_word(1023)
print(f"Result at address 1023: 0x{result:08X} ({result})")
print("Expected: 0x00000010 (16)")   # 2 << 3 = 16 for test1
```

### Step 6 — Verify

Expected result for `test_programs/test1/src/main.c`:

```
f = 2, g = 3
y = func(f, g) = 2 << 3 = 16
Memory[4092] = 16 (0x00000010)
```

The C program writes `y = 16` to byte address 4092 (`int *ptr = (int *)(4096 - 4)`), which is word 1023 in the BRAM. Reading that address from Python via the AXI BRAM Controller should return `0x00000010`.

---

## Signal Reference

### `bram_wrapper.v` / `riscv_wrapper.v` port mapping to BRAM

| Wrapper port | BRAM Port B pin | Direction | Description |
|---|---|---|---|
| `bram_clk` | `clkb` | wrapper→BRAM | Clock (tie to `FCLK_CLK0`) |
| `bram_en` | `enb` | wrapper→BRAM | Enable (tie high) |
| `bram_we[3:0]` | `web[3:0]` | wrapper→BRAM | Byte write enable |
| `bram_addr[31:0]` | `addrb[31:0]` | wrapper→BRAM | Byte address |
| `bram_din[31:0]` | `dinb[31:0]` | wrapper→BRAM | Write data |
| `bram_dout[31:0]` | `doutb[31:0]` | BRAM→wrapper | Read data (1-cycle latency) |
| `bram_rst` | `rstb` | wrapper→BRAM | Synchronous reset (tie low) |

> **BRAM Read Latency**: With no output register, data appears on `doutb` **one clock cycle** after the address is registered. Account for this in your CPU's memory access timing.
