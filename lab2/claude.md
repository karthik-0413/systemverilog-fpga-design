# Navigate to your lab2 directory
cd lab2

# Open Vivado with your project
vivado project_name.xpr
```

*Replace `project_name.xpr` with your actual project file name*

Once Vivado opens, you should see the **Flow Navigator** panel on the left side.

---

## **1. Max Frequency (MHz)**

### **Method A: From Timing Summary Report**

**Steps:**
1. In the **Flow Navigator** (left panel), look for **IMPLEMENTATION**
2. Click on **"Open Implemented Design"** (if not already open)
   - This may take a minute to load
3. Once the implemented design is open, in the top menu bar:
   - Click **Reports → Timing → Report Timing Summary**
4. A dialog box will appear:
   - Click **OK** (default settings are fine)

**What to look for:**
- The report will open in the bottom panel
- Look at the **"Design Timing Summary"** section at the top
- Find the line that says something like:
```
  WNS(ns)      TNS(ns)  TNS Failing Endpoints  TNS Total Endpoints      WHS(ns)
    X.XXX        0.000                      0                  XXXX        X.XXX
```

**Reading the results:**
- **WNS (Worst Negative Slack)**: If this is **POSITIVE**, timing is met
  - Example: WNS = 2.5 ns means you have 2.5 ns of margin
  - If NEGATIVE, timing failed

**To find Max Frequency:**
- Look for your clock constraint in the report
- It will show something like:
```
  Clock Summary
  Clock        Period(ns)  Frequency(MHz)  WNS(ns)  TNS(ns)
  clk_fpga_0      10.000          100.000    2.500    0.000
```
- The **Frequency(MHz)** column shows your achieved frequency

**If you want to calculate it manually:**
```
Clock Period = 10 ns (this is your constraint, usually 100 MHz = 10 ns period)
WNS = 2.5 ns (your slack)
Critical Path Delay = Period - WNS = 10 - 2.5 = 7.5 ns
Max Frequency = 1000 / Critical_Path_Delay = 1000 / 7.5 = 133.3 MHz
```

**Write down:**
```
Max Frequency: ___ MHz
```

---

## **2. Critical Path (ns)**

**Still in the Timing Summary Report from Step 1:**

**Steps:**
1. In the same Timing Summary report, scroll down
2. Look for the section **"Intra Clock Table"** or **"Max Delay Paths"**
3. Find the entry for your main clock (e.g., `clk_fpga_0`)
4. Look at the **"Requirement"** and **"Slack"** columns

**Calculate Critical Path:**
```
Critical Path = Clock Period - WNS
```

Example:
```
Clock Period = 10.0 ns
WNS = 2.5 ns
Critical Path = 10.0 - 2.5 = 7.5 ns
```

### **Method B: Detailed Path Report**

For more detailed information:

**Steps:**
1. In top menu: **Reports → Timing → Report Timing**
2. In the dialog that opens:
   - **Delay Type**: max delay
   - **Max paths**: 10 (to see top 10 worst paths)
   - Click **OK**

**What to look for:**
- The report shows the detailed path breakdown
- At the top, you'll see:
```
  Slack (MET) :             2.500ns  (required time - arrival time)
  Source:                   some_reg/C
  Destination:              another_reg/D
  Data Path Delay:          7.500ns
```
- **Data Path Delay** is your critical path delay

**Write down:**
```
Critical Path: ___ ns
```

---

## **3. LUT Usage**

**Steps:**
1. In **Flow Navigator** (left panel), under **IMPLEMENTATION**
2. Make sure **"Open Implemented Design"** is open
3. In top menu: **Reports → Report Utilization**
4. A dialog appears - click **OK**

**What to look for:**
- The report opens in the bottom panel
- Look for the **"Slice Logic"** section
- Find the row labeled **"Slice LUTs"** or just **"LUT as Logic"**

**Example:**
```
Slice LUTs                     used     available     utilization
LUT as Logic                    523        53200           0.98%
```

**Write down:**
```
LUT Usage: 523 (or whatever your number is)
or
LUT Usage: 0.98% (percentage)
```

**Tips:**
- If you see multiple LUT categories (LUT as Logic, LUT as Memory, etc.), use **"Slice LUTs"** for the total
- The percentage is what goes in your table for easy comparison

---

## **4. DSP Usage**

**Still in the Utilization Report from Step 3:**

**Steps:**
1. In the same report, scroll down to find the **"DSP"** section
2. Look for **"DSPs"** or **"DSP48E1"** (PYNQ-Z1 uses DSP48E1)

**Example:**
```
DSP
DSP48E1                          0          220           0.00%
```

**Write down:**
```
DSP Usage: 0 (for Part 1 - adder should use 0 DSPs)
```

**Note:** For your FIR filter parts (2, 3, 4), this number will be significant!
- Part 2 (Parallel FIR): Will use N DSPs (where N = number of filter taps)
- Part 3 (Pipelined FIR): Will use N DSPs
- Part 4 (Area-Optimized FIR): Will use ~1 DSP

---

## **5. BRAM Usage**

**Still in the Utilization Report:**

**Steps:**
1. In the same report, find the **"Memory"** or **"BRAM"** section
2. Look for **"Block RAM Tile"** or **"RAMB36/FIFO"** and **"RAMB18"**

**Example:**
```
Memory
Block RAM Tile                   0          140           0.00%
  RAMB36/FIFO                    0          140           0.00%
  RAMB18                         0          280           0.00%
```

**Write down:**
```
BRAM Usage: 0 (for Part 1)
or
BRAM Usage: 0.00%
```

**Note:** 
- Part 1 should use 0 BRAMs (simple adder doesn't need memory)
- FIR filters will use BRAMs for coefficient storage
- RAMB36 = 36Kb blocks, RAMB18 = 18Kb blocks
- Count the total used (usually report as RAMB36 equivalent)

---

## **6. Latency (cycles)**

**This comes from your SIMULATION, not from Vivado reports!**

**Steps:**
1. Go back to your simulation waveform (the one you have open from running `run_sim.sh`)
2. Add these signals to the waveform if not already visible:
   - Input `TVALID`
   - Input `TDATA`
   - Output `TVALID`
   - Output `TDATA`
   - Clock signal (`clk`)

**How to measure:**
1. Find the first clock cycle where input `TVALID` goes high AND input data is present
2. Note the clock cycle number (or use cursor)
3. Find the clock cycle where the corresponding output appears (output `TVALID` goes high with the result)
4. Count the number of clock cycles between them

**Example:**
```
Input arrives at cycle 10
Output appears at cycle 13
Latency = 13 - 10 = 3 cycles
```

**Visual method in waveform:**
1. Right-click on the waveform → **Add Cursors**
2. Place **Cursor 1** at the input data arrival
3. Place **Cursor 2** at the corresponding output
4. The delta between cursors shows the latency

**Write down:**
```
Latency: ___ cycles
```

---

## **7. Throughput (Msamp/s)**

**This is calculated from Max Frequency and pipeline behavior:**

### **Method A: Theoretical Throughput**

**Formula:**
```
Throughput (Msamp/s) = Max Frequency (MHz) × Samples per Cycle
```

**For a fully pipelined design:**
- Samples per cycle = 1 (can accept new input every cycle after initial latency)

**Example:**
```
Max Frequency = 100 MHz
Samples per cycle = 1
Throughput = 100 × 1 = 100 Msamp/s
```

**Write down (for now):**
```
Throughput (theoretical): ___ Msamp/s