# Lab 1

This lab teaches RTL design, SystemVerilog verification, and FPGA deployment to Pynq-Z1 for simple combinational circuits.


## Vivado Access Required

You will need access to Xilinx Vivado 2025.1 for this lab. Choose one of the following options:

### Option 1: Remote Access via CRC (Recommended for Quick Start)
Access Vivado through the CRC computing cluster make sure to connect to [Pitt VPN](https://crc-pages.pitt.edu/user-manual/web-portals/open-ondemand/):

- Go to CRC [Hugen portal](https://hugen.crc.pitt.edu/pun/sys/dashboard)
- Open a **Code Server** for VS Code in your browser, OR
- Open a **Teach Desktop** for an interactive desktop environment
- Account: ece1195_2026s
- After opening desktop or code server load vivado by running 'module load FPGA/Vivado/2025.1' in the terminal. Open vivado by typing in 'vivado'

### Option 2: Local Installation
Install Vivado 2025.1 ML Standard Edition (free) on your computer:
- Download from [Xilinx/AMD Website](https://www.xilinx.com/support/download.html)
- Select **Vivado ML Standard Edition 2025.1**
- Free registration required

## Lab1 files

You can find lab1 files in

```bash
cd /ix/ece1195_2026s/lab1
```

## Vivado Setup for Pynq Z1

Create a file: ~/.Xilinx/Vivado/Vivado_init.tcl with the following contents
```tcl
set_param board.repoPaths [list "/ix/ece1195_2026s/pynqz1_board_files/pynq-z1"]
```

Alternatively you can run this shell command to copy the file
```bash
 cp /ix/ece1195_2026s/Vivado_init.tcl ~/.Xilinx/Vivado/2025.1/Vivado_init.tcl
```

When you open vivado you should see Sourcing tcl script '~/.Xilinx/Vivado/2025.1/Vivado_init.tcl'

If you run the following command in the TCL shell

```tcl
get_board_parts *pynq*
```

you should see the following output: www.digilentinc.com:pynq-z1:part0:1.0

---

## Lab 1 Basics: Adder

Copy the lab files from course directory to your work directory
```bash
cd ~
mkdir ece1195_labs
cd ece1195_labs
cp -r /ix/ece1195_2026s/lab1 .
cd lab1
```
You can open this folder from CRC Hugen Code Server to view the files in VS Code

**Part 1**: RTL Design & Simulation - See [Simulation Testbenches](#simulation-testbenches-for-16-bit-adder)

**Part 2**: Vivado Block Design - See [Vivado Block Design and Bitstream Generation](#part-2-vivado-block-design-and-bitstream-generation)

**Part 3**: PYNQ Deployment - See [PYNQ Deployment and Testing](#part-3-pynq-deployment-and-testing)


## Lab 1 Exercise : ALU

**See** [Lab Exercise: 16-bit ALU Design](#lab-exercise-16-bit-alu-design)

---

# Simulation Testbenches for 16-bit Adder

This directory contains testbenches to verify the 16-bit adder design.

## Three Implementation Variations

The adder design ([rtl/adder_16bit.sv](../rtl/adder_16bit.sv)) supports three different implementations. All produce identical results.

### 1. BEHAVIORAL (Default)
Uses the `+` operator. Simple and readable.
```systemverilog
assign result = {1'b0, a} + {1'b0, b};
```

### 2. RIPPLE_CARRY_MANUAL
Manually instantiates 16 full adders one-by-one. Shows explicit connections.
```systemverilog
full_adder fa0 (.a(a[0]), .b(b[0]), .cin(c[0]), .sum(sum[0]), .cout(c[1]));
full_adder fa1 (.a(a[1]), .b(b[1]), .cin(c[1]), .sum(sum[1]), .cout(c[2]));
...
```

### 3. RIPPLE_CARRY_GENERATE
Uses `generate` statement with a for loop. Scalable and easy to modify.
```systemverilog
generate
    for (i = 0; i < 16; i = i + 1) begin
        full_adder fa (...);
    end
endgenerate
```

---

## Testbenches

### 1. Exhaustive Testing (`tb_adder_exhaustive.sv`)
- Tests MAXVAL x MAXVAL combinations (default: 256x256 = 65K tests)
- **Note**: This runs only a SUBSET of all possible combinations for speed
- Full exhaustive would be 2^32 = 4.3 billion tests
- Change MAXVAL in the file to test more combinations
- Run with MAXVAL = 65536 by editing the file and check the time to run (Ctrl+C to stop)
- Simple driver/monitor/scoreboard
- Used by: `run_behavioral.sh`, `run_manual.sh`, `run_generate.sh`

### 2. Constrained Random Testing (`tb_adder_constrained_random.sv`)
- Tests corner cases (0, max, MSB/LSB patterns)
- 10,000 random tests with smart distribution (30% corner cases, 70% random)
- Simple classes for transactions
- Automatic result checking
- Better coverage than exhaustive due to smarter test selection
- Used by: `run_coverage.sh` (default)

---

## Quick Start

### Step 1: Test each implementation (uses exhaustive testbench)
```bash
cd sim
./run_behavioral.sh    # Test behavioral implementation
./run_manual.sh        # Test manual instantiation
./run_generate.sh      # Test generate statement
./run_waveform.sh      # Shows how to save & view simulation waveforms
```

All these tests use `tb_adder_exhaustive.sv` testbench which tests 256x256 = 65K input combinations. 

Note: The run_waveform.sh script will open Vivado GUI. Select Window --> Waveform from the menu bar to view the simulation waveform. Zoom into the waveform and check for the for loop pattern in a & b corresponding to the testbench.

### Step 2: Understand Coverage - Why Exhaustive Isn't Feasible

Modify `run_coverage.sh` to use the exhaustive testbench:

**Edit line 17 in run_coverage.sh**:
```bash
# Change from:
xvlog -sv tb_adder_constrained_random.sv || exit 1

# To:
xvlog -sv tb_adder_exhaustive.sv || exit 1
```

**And edit line 25**:
```bash
# Change from:
xelab -debug typical tb_adder_constrained_random -s sim \

# To:
xelab -debug typical tb_adder_exhaustive -s sim \
```

Then run and generate coverage report:
```bash
./run_coverage.sh
```
**TODO**: Check the script for the command that reports coverage. Then open the generated coverage report (HTML) using firefox. Click on the Files in the top menu and select the adder DUT. Then check the branch, conditional, and toggle coverage.

```bash
firefox xsim_coverage_report/codeCoverageReport/dashboard.html
```

**Observation**: Report the toggle coverage for the DUT from the dashboard.html file that is generated. It will be around 50%. 

**Why?** The exhaustive testbench only tests values 0-255, so upper bits [15:8] barely toggle. Running with MAXVAL = 65536 takes too long to be practical but will result in 100% coverage. You can edit the MAXVAL in tb_adder_exhaustive.sv to 65536 and then run it to observe the simulation progress.

### Step 3: Better Coverage with Constrained Random

Now change `run_coverage.sh` back to use constrained random testbench:

**Edit line 17 in run_coverage.sh**:
```bash
# Change back to:
xvlog -sv tb_adder_constrained_random.sv || exit 1
```

**And edit line 25**:
```bash
# Change back to:
xelab -debug typical tb_adder_constrained_random -s sim \
```

Then run and generate coverage report:
```bash
./run_coverage.sh
```

**Result**: Check the coverage again.  Report the toggle coverage for the DUT from the dashboard.html file that is generated. Much better toggle coverage!

**Why?** The constrained random testbench exercises corner cases and full bit ranges with minimal test cases.

---

## Learning Points

By running these tests, you'll understand:

1. **Three ways to describe hardware**:
   - Behavioral (what you want)
   - Structural manual (explicit connections)
   - Structural generate (programmatic instantiation)

2. **They all produce the same hardware** (after synthesis)

3. **Generate statements** make designs scalable (change 16 to 32 easily!)

4. **Exhaustive vs. Random Testing**:
   - Exhaustive testing is often not feasible. Testing a subset (256x256) gives poor coverage
   - Constrained random testing (10K tests) gives better coverage
   - **Key insight**: Smart test selection > brute force

5. **Code Coverage Metrics**:
   - Toggle coverage: Which bits flipped 0→1 and 1→0
   - Branch/Condition coverage: Decision logic exercised (if included)

---

# Part 2: Vivado Block Design and Bitstream Generation

In this section, we will create a block design which contains our adder design and connect it to the processing system (CPU) on the FPGA and generate a PYNQ overlay (bitstream & HW descreption file) so that we can test the adder on the FPGA usign Python scripts. 

This part explains how the `recreate_bd.tcl` script automates the creation of the Vivado project, block design, and bitstream files. Please read the TCL script to understand the primary components. 

Notes: 
- Vivado cannot instantiate a system verilog file directly as an IP. So we need a Verilog wrapper as in rtl/add_16bit_wrapper.v which just instantiates the SV adder DUT.
- For the ALU exercise, you can either modify the script or modify the block diagram in the GUI. Make sure to create a Verilog wrapper for ALU and import the correct files in the script.
- If you modify in GUI, you can save it after adding AXI GPIO IPs as needed. But you will need to validate the board design, save it and then run the remaining TCL commands for setting up the wrapper, synthesis, implementation, and exporting the overlay on TCL shell in the GUI.

## Overview

The `recreate_bd.tcl` script performs the following steps:

1. **Create Vivado Project**: Sets up a new Vivado project for the PYNQ-Z1 board (xc7z020clg400-1).

2. **Add RTL Sources**: Imports the SystemVerilog RTL files (`adder_16bit.sv`, `full_adder.sv`) and Verilog wrapper (`adder_16bit_wrapper.v`).

3. **Create Block Design**:
   - Adds Processing System 7 (PS) IP core
   - Adds two AXI GPIO IP cores (one for inputs, one for outputs)
   - Adds the custom adder wrapper module
   - Connects the components via AXI interfaces

4. **Configure GPIO**:
   - GPIO 0: 17-bit input (for reading the 17-bit sum result)
   - GPIO 1: Dual channel, 16-bit each (for a and b inputs)

5. **Automate Connections**: Uses Vivado's automation rules to connect PS to GPIO via AXI.

6. **Generate Wrapper**: Creates the top-level design wrapper.

7. **Run Synthesis**: Synthesizes the design.

8. **Run Implementation**: Places and routes the design.

9. **Generate Bitstream**: Creates the FPGA programming file.

10. **Export Hardware**: Generates the XSA file containing the bitstream and hardware description.

## Running the Script

```bash
# In the lab1 directory
cd lab1
vivado -mode batch -source recreate_bd.tcl
```
OR

Open vivado in lab1 directory and run the following command in the TCL shell to see the block diagram interactively generated.
```tcl
source ./recreate_bd.tcl
``` 

This produces the `my_overlay.xsa` file in the `proj1/export/` directory, which contains the bitstream and hardware handoff files needed for PYNQ deployment.

## Key Components

- **Processing System 7**: Zynq ARM processor and peripherals
- **AXI GPIO**: Bridges between AXI bus and GPIO pins for data transfer
- **Adder Wrapper**: Custom RTL module instantiated in the block design

The block design connects the PS to the adder via GPIO, allowing software running on the ARM processor to control the adder inputs and read outputs.

---

# Part 3: PYNQ Deployment and Testing

This part covers deploying the overlay to the PYNQ-Z1 board and testing the adder functionality using Python.

## Overlay Preparation

Follow the steps in [Overlay Preparation and Deployment](#overlay-preparation-and-deployment) to:

1. Extract overlay files from the XSA archive
2. Copy files to your local machine
3. Deploy overlay files to the PYNQ board

The overlay files (`lab1_overlay.hwh` and `lab1_overlay.bit`) should be placed in `/home/xilinx/overlays/` on the PYNQ board.

## Loading the Overlay in Python

Use the PYNQ Overlay class to load the bitstream:

```python
from pynq import Overlay

# Load the overlay
ol = Overlay("/home/xilinx/overlays/lab1_overlay.bit")
```

## Accessing GPIO Channels

The overlay exposes three GPIO channels:

```python
io = {
    "a": ol.axi_gpio_1.channel1,      # 16-bit input a
    "b": ol.axi_gpio_1.channel2,      # 16-bit input b
    "sum": ol.axi_gpio_0.channel1     # 17-bit output sum
}
```

## Testing the Adder

See [`lab1_add_test_notebook.py`](lab1_add_test_notebook.py) for a complete example of:

- Loading the overlay
- Setting up GPIO channels
- Single test case verification
- Automated random testing with 1000 iterations

The example includes a `test_adder()` function that generates random 16-bit inputs, writes them to the FPGA, reads back the sum, and verifies correctness. 

## Running on PYNQ

1. Connect to PYNQ Jupyter notebook interface
2. Create a new Jupyter notebook on your PYNQ board based on the python example provided above.
3. Execute the cells to load overlay and run the tests
4. Verify that the hardware adder produces correct results

This demonstrates end-to-end FPGA deployment: RTL design → SV Verification → Vivado synthesis → PYNQ overlay → Python testing.

---

# Overlay Preparation and Deployment

This guide outlines the steps to extract the overlay files from the XSA archive and deploy them to the PYNQ board.

## On the Remote Machine (where Vivado project is located)

```bash
# Copy the XSA file to ZIP (XSA is essentially a ZIP archive)
cp proj1/export/my_overlay.xsa proj1/export/my_overlay.zip

# Change to the export directory
cd proj1/export/

# Unzip the archive
unzip my_overlay.zip

# Rename the hardware description file
mv design_1.hwh lab1_overlay.hwh

# Rename the bitstream file
mv my_overlay.bit lab1_overlay.bit
```

## Copy Files to Local Machine

```bash
# Copy the overlay files from remote to local machine in a temporary directory
scp <username>@h2p.crc.pitt.edu:<path_to_files>
e.g.: scp pr3@h2p.crc.pitt.edu:/ihome/pmohan/pr3/ece1195_labs/lab1/proj1/export/lab1_overlay.* .
```

## Deploy to PYNQ Board

```bash
# SCP the overlay files to the PYNQ board
scp lab1_overlay.* xilinx@192.168.2.99:/home/xilinx/overlays/
```

## Notes

- The overlay files (`lab1_overlay.hwh` and `lab1_overlay.bit`) should now be available in the `/home/xilinx/overlays/` directory on the PYNQ board.
- Create the `overlays` directory if it does not exist
- Update IP addresses, usernames, and paths as needed for your specific setup.

---



# Lab Exercise: 16-bit ALU Design

Recreate the same project structure as the adder example, but implement a 16-bit ALU (Arithmetic Logic Unit) that performs various operations based on a control signal. The ALU should treat all inputs and outputs as signed values.

## Specifications

### Inputs
- `a`: 16-bit signed input
- `b`: 16-bit signed input
- `shift_amount`: 5-bit signed input (-16 to +15)
- `control`: 3-bit control signal (see table below)

### Output
- `result`: 32-bit signed output

### Control Signal Table

| Control [2:0] | Operation | Description | Result |
|---------------|-----------|-------------|--------|
| 000 | ADD | Signed addition | `a + b` (sign-extended to 32 bits) |
| 001 | SUB | Signed subtraction | `a - b` (sign-extended to 32 bits) |
| 010 | MUL | Signed multiplication | `a * b` (full 32-bit result) |
| 011 | AND | Bitwise AND | `a & b` (zero-extended to 32 bits) |
| 100 | OR | Bitwise OR | `a \| b` (zero-extended to 32 bits) |
| 101 | XOR | Bitwise XOR | `a ^ b` (zero-extended to 32 bits) |
| 110 | SHIFT | Variable shift | If `shift_amount >= 0`: `a << shift_amount` (arithmetic left shift)<br>If `shift_amount < 0`: `a >> (-shift_amount)` (arithmetic right shift)<br>Result sign-extended to 32 bits |
| 111 | INVALID | Reserved | This control value is invalid and must not be used in testbenches |

### Notes
- For arithmetic operations (ADD, SUB, MUL), treat inputs as signed 16-bit integers and produce signed 32-bit results.
- For logical operations (AND, OR, XOR), perform bitwise operations on the 16-bit inputs and zero-extend the result to 32 bits.
- For shift operations, perform arithmetic shifts (signed) on the 16-bit input `a` by 1 position, then sign-extend to 32 bits.
- The result is always 32 bits wide to accommodate multiplication results and provide consistent output width.

## Tasks
1. Create the SystemVerilog ALU module (`alu_16bit.sv`)
2. Create testbenches for verification similar to adder example.
    Note: start using a simple testbench to verify basic functionality for a few inputs. Then use constrained random verification to achieve good test coverage. Ensure only valid inputs are provided and report the test coverage.
3. Create a Verilog wrapper (`alu_16bit_wrapper.v`) for Vivado block design compatibility
4. Update the block design to use the ALU instead of the adder
5. Create a block diagram, generate the bitstream and deploy to PYNQ
6. Write a Python test script to verify functionality (similar to the testbench) with randomized inputs while ensuring only valid inputs are provided.

Follow the same project structure and testing methodology as the adder example.
