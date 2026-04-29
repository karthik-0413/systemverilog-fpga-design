# Lab 2: Streaming Data Processing with PYNQ - FIR Filter Implementation

## Overview
This lab involves implementing and optimizing a fully parallel and pipelined FIR filter for streaming data processing on a PYNQ board. You will progress from a simple pipelined adder design to increasingly optimized FIR filter implementations.

Lab2 files in `/ix/ece1195_2026s/lab1`

Please refer to Lab1 to refresh on basic commands and tools as you will be repeating similar steps in lab2 as well.


---

## Part 1: Baseline System with Pipelined Adder

### Step 1: Run Verilog Simulation
Run the Verilog simulation for the pipelined adder design in the provided testbench.

**Location:** `axis_example/sim/`

**Command:**
```bash
cd axis_example/sim
bash run_sim.sh
```

**Steps:**
- Execute the simulation script to verify the pipelined adder functionality
- Examine the generated waveforms (`.wdb`) to ensure proper AXI-Stream protocol compliance
- Verify that:
  - TVALID and TREADY handshaking works correctly
  - Data flows through the pipeline without corruption
  - Output arrives at correct clock cycles based on pipeline depth

### Step 2: Compile Vivado Project and Export XSA File
Use the provided `generate_board.tcl` script to compile the Vivado project with DMA and adder instantiation.

**Steps:**
- Execute the TCL script: `source generate_board.tcl` (in Vivado or via command line as shown below)
   ```bash
   # In the lab1 directory
   cd lab2
   vivado -mode batch -source generate_board.tcl
   ```
- The script should configure the block diagram with:
  - AXI DMA for streaming data input/output
  - Pipelined adder IP instantiated & AXI GPIO
- Export the hardware description as an `.xsa` file (Xilinx Support Archive) in export directory similar to lab1

### Step 3: Extract Bitstream and Hardware Handoff Files
Following the lab1 methodology, extract and prepare files for PYNQ deployment.

**Steps:**
- Extract `.bit` (bitstream) file from the Vivado build output
- Extract `.hwh` (hardware handoff) file
- Copy the overlay (`.bit` + `.hwh`) to the PYNQ board
- Place files in the appropriate overlay directory on the board

### Step 4: Verify Streaming Data from DRAM
Run the provided Jupyter notebook on the PYNQ board to validate the system.

**Verification:**
- Execute the notebook to stream data from DRAM through the DMA
- Confirm that data is correctly processed by the pipelined adder
- Check streaming throughput and data integrity

---

## Part 2: Fully Parallel FIR Filter Implementation

### Step 1: Implement and Simulate Fully Parallel FIR Filter
Design a fully parallel FIR filter based on the golden model provided in the `fir_golden_model/` directory.

**FIR Filter Details:**
- **Architecture:** Fully combinational parallel implementation (all taps computed in parallel)
- **Data Path:** Shift register with simultaneous MAC operations for all filter coefficients
- **Output Size:** Produces 1000 - 63 = 937 valid output samples (where 63 is the filter length - 1)
- **Coefficients:** 64-tap FIR filter with pre-computed coefficients
  - **Low-Pass (LP) coefficients:** `lp_coefficients.txt` (64 coefficients)
  - **High-Pass (HP) coefficients:** `hp_coefficients.txt` (64 coefficients)
- **Files Exported:** Pre-generated test vectors (1000 samples) for simulation validation

**Simulation Setup:**
- Modify the AXI-Stream adder testbench to accommodate the FIR filter (located in `axis_example/sim/tb_axis_adder.v`)
- Update testbench to instantiate FIR filter instead of adder
- Load test vectors from `fir_golden_model/verilog_files/`:
  - **Input signal:** `input_signal.txt` (1000 samples)
  - **Low-Pass (LP) expected output:** `lp_output_expected.txt` (937 samples)
  - **High-Pass (HP) expected output:** `hp_output_expected.txt` (937 samples)

**Verilog Files to Use:**
- FIR filter module: `fir_filter_parallel.v` (fully parallel implementation)
- Testbench: Modify `tb_axis_adder.v` to create `tb_fir_filter.v`

**Design Requirements - Configurable Coefficient Loading:**

The FIR filter must support dynamic coefficient loading via an **AXI GPIO signal** to switch between LP and HP filter modes:

- **Signal Name:** `stream_load_coeff_en` (AXI GPIO control signal)
  - **When `stream_load_coeff_en = 1`:** Incoming AXI-Stream data loads into the coefficient shift register
  - **When `stream_load_coeff_en = 0`:** Incoming AXI-Stream data flows to the data shift register (normal filtering mode)

- **Coefficient Shift Register:** 64-tap register to hold filter coefficients
  - Load coefficients by setting `stream_load_coeff_en = 1` and streaming 64 samples via AXI-Stream
  - After loading coefficients, set `stream_load_coeff_en = 0` to begin data filtering

- **Configurability:** This design allows the same FIR hardware to function as either LP or HP filter by loading different coefficient sets

**Critical Requirements:**
- Assert `TLAST` on the AXI-Stream output interface when the last valid sample is produced
- Ensure output stops after all 1000 input samples are processed
- Valid outputs begin only when the entire shift register contains valid data (after 63 clock cycles)
- Properly handle `stream_load_coeff_en` transitions and coefficient loading protocol

**Run Simulation - Create TB and scripts to test both LP and HP filters:**

The testbench must implement the coefficient loading protocol using `stream_load_coeff_en`:

1. **Load Low-Pass Coefficients:**
   - Set `stream_load_coeff_en = 1`
   - Stream 64 LP coefficients via AXI-Stream input
   - Set `stream_load_coeff_en = 0`

2. **Stream Data and Capture LP Output:**
   - Stream 1000 input samples via AXI-Stream
   - Capture 937 valid LP output samples

3. **Load High-Pass Coefficients:**
   - Set `stream_load_coeff_en = 1`
   - Stream 64 HP coefficients via AXI-Stream input
   - Set `stream_load_coeff_en = 0`

4. **Stream Data and Capture HP Output:**
   - Stream 1000 input samples via AXI-Stream
   - Capture 937 valid HP output samples

```bash
cd axis_example/sim
# Simulate Low-Pass filter
bash run_sim_lp.sh
# Simulate High-Pass filter
bash run_sim_hp.sh
```

**Verify Output - Both Configurations:**

*Low-Pass Filter:*
- Compare LP output samples with `lp_output_expected.txt`
- Check that exactly 937 valid LP samples are produced
- Confirm TLAST is asserted on the final output sample

*High-Pass Filter:*
- Compare HP output samples with `hp_output_expected.txt`
- Check that exactly 937 valid HP samples are produced
- Confirm TLAST is asserted on the final output sample

*General Checks:*
- Examine waveforms for correct data flow and AXI-Stream protocol compliance
- Verify both filters process the same input signal correctly

**Expected Output Behavior:**
- Inputs: 1000 samples via AXI-Stream (TVALID and TLAST control)
- Outputs: 937 valid samples with proper TLAST assertion on final output sample
- Simulation should show correct filter responses and protocol compliance

### Step 2: Integrate FIR Filter into Vivado Block Diagram
Incorporate the fully parallel FIR filter into your Vivado project with coefficient control.

**Steps:**
- Modify the TCL script or use GUI as needed to create a new block diagram with FIR filter in palce of adder in the example
- Add the FIR IP to the block diagram alongside the DMA controller
- Connect AXI-Stream interfaces
- **Add AXI GPIO Controller**
  - Create AXI GPIO IP block for control signals
  - Connect GPIO output bit to FIR `stream_load_coeff_en` signal
  - This allows software to switch between coefficient loading and data streaming modes
- Generate overlay

### Step 3: Timing and Area Analysis
Analyze and report post-place-and-route (PAR) results.

**Report the following:**
- **Timing:** Critical path delay to the output register of the FIR filter
- **Timing Paths:** Any internal pipeline paths if pipelined logic was added
- **Area Utilization:**
  - LUT usage
  - DSP48 (multiplier) usage
  - BRAM blocks used
  - Slice and resource breakdown

### Step 4: Validate on PYNQ Board
Deploy and test the FIR filter overlay on PYNQ board.

**Testing:**
- Load the generated overlay (`.bit` + `.hwh`) onto the PYNQ board
- Create a Jupyter notebook to run simulation with 1000 samples
- Verify filtered output matches golden model
- **Extended Testing:** Repeat simulation with 250K full dataset
- Verify data integrity and calculate throughput for extended run (simulation extimate vs timeit in notebook)

---

## Part 3: Throughput-Optimized Pipelined FIR Filter

### Objective
Optimize the FIR filter for maximum throughput by achieving the highest clock frequency via pipelining.

### Implementation Strategy
- Introduce pipeline registers at strategic locations (typically after partial accumulation stages)
- Balance pipeline depth to minimize combinational delay while not introducing excessive area overhead
- Maintain AXI-Stream protocol compliance with proper TLAST generation

### Deliverables
Repeat all steps from **Part 2** with the pipelined FIR filter:

1. **Simulation:** Verify correctness with modified testbench (1000 samples)
   - Ensure TLAST is asserted correctly
   - Validate output sample count (937 valid samples)

2. **Block Diagram Integration:** Add pipelined FIR IP to Vivado project
   - Generate bitstream with timing constraints met

3. **Timing & Area Report:**
   - Report critical path delay (should be significantly improved vs. Part 2)
   - Report maximum achievable frequency
   - Compare area utilization vs. parallel implementation
   - Document pipeline depth and latency

4. **Hardware Validation (1000 + 250K samples):**
   - Deploy overlay on PYNQ
   - Verify output correctness with both dataset sizes
   - Measure actual throughput on hardware

---

## Part 4: Area-Optimized FIR Filter (Resource Constrained)

### Objective
Optimize the FIR filter for area efficiency using minimal hardware resources.

### Implementation Constraints
- **1 Multiplier (DSP48):** Single MAC operation per clock cycle
- **1 BRAM (Dual-Port):** Store coefficients and intermediate data
- **FSM-Based Sequencing:** Control finite state machine to orchestrate multiply-accumulate operations

### Architecture Overview
- **Input Buffer:** Store incoming samples
- **Coefficient Storage:** One coefficient per cycle via BRAM
- **Sequential MAC:** Process all taps over multiple cycles
- **Output Control:** Produce valid output only when computation is complete; assert TLAST appropriately

### Implementation Strategy
Design an FSM that:
1. Reads input sample(s) and buffers them in BRAM
2. Sequentially reads coefficients and performs MAC operations (64 MACs per output for 64-tap filter)
3. Accumulates partial results
4. Outputs valid samples with correct TLAST timing
5. Manages the pipeline to produce one output every N cycles (where N ≥ 64)

### Deliverables
Repeat all steps from **Part 2** with the area-optimized FIR filter:

1. **Simulation (1000 samples):**
   - Verify FSM operation and sequential MAC pipeline
   - Confirm output correctness and TLAST assertion
   - Validate output count (937 valid samples)

2. **Block Diagram Integration:** Add area-optimized FIR IP
   - Generate bitstream

3. **Timing & Area Report:**
   - Report critical path delay (may be limited by single MAC)
   - Report area utilization (should be minimal: ~1 DSP, ~1 BRAM, few LUTs)
   - Compare vs. Parts 2 and 3
   - Document maximum throughput (samples per second)

4. **Hardware Validation (1000 + 250K samples):**
   - Deploy overlay on PYNQ
   - Verify functional correctness
   - Measure throughput vs. pipelined version
   - Note any performance trade-offs

---

## Comparison Summary

Upon completion of all four parts, prepare a summary table comparing:

| Metric | Part 1 (Adder) | Part 2 (Parallel FIR) | Part 3 (Pipelined FIR) | Part 4 (Area-Opt FIR) |
|--------|---|---|---|---|
| **Max Frequency (MHz)** | | | | |
| **Critical Path (ns)** | | | | |
| **LUT Usage** | | | | |
| **DSP Usage** | | | | |
| **BRAM Usage** | | | | |
| **Latency (cycles)** | | | | |
| **Throughput (Msamp/s)** | | | | |

---

## Submission Requirements

1. **Simulation Results:** verilog, testbenches and output simulation logs for all designs
2. **Vivado Project:** TCL, bitstreams, and hardware handoff files
3. **Analysis Reports:** Timing and area utilization for each part
4. **PYNQ Test Scritps:** Jupyter notebook
5. **Comparison Document:** Summary of trade-offs and observations
6. **AI Use:** Breif paragraph or bullets on how you used Gen AI tools.

## Points

1. **Part1:** 5
2. **Part2:** 30
3. **Part3:** 30
4. **Part3:** 35