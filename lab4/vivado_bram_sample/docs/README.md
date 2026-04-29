# BRAM AXI Test Design for PYNQ-Z1

## Project Structure

```
vivado_bram_sample/
├── src/                    # RTL source files
│   ├── bram_test_fsm.sv   # FSM module
│   └── bram_wrapper.v      # Block design wrapper
├── scripts/                # Build scripts
│   └── create_project.tcl  # Vivado project creation script
├── docs/                   # Documentation
│   └── README.md          # This file
├── test/                   # Test files
│   └── test_bram_overlay.ipynb # PYNQ test notebook
└── export/                # Generated files (created by build)
    └── bram_test_overlay.xsa   # Generated overlay
```

## Overview

This project creates a complete Vivado design and PYNQ test for a dual-port BRAM with AXI access and FSM control.

## Design Architecture

- **Target Platform**: PYNQ-Z1 (xc7z020clg400-1)
- **BRAM**: 4K bytes (1024 × 32-bit words) using Xilinx Block Memory Generator
- **Port A**: AXI BRAM Controller for Python access
- **Port B**: Custom FSM with RISC-V-style interface
- **Control**: AXI GPIO for FSM start/done signals

## FSM Functionality

The FSM performs these operations:
1. Read address 0, 1, 2, 3 (bottom 4 locations)
2. Calculate sum of the 4 values
3. Store result at address 1023 (top location)
4. Signal completion via GPIO

## GPIO Control

- **GPIO Channel 0 (Output)**: Bit 0 = start signal (level-triggered)
- **GPIO Channel 1 (Input)**: Bit 0 = busy, Bit 1 = done

**Control Sequence**:
1. Ensure start=0 (done should be 0)
2. Set start=1 (begin operation)
3. Wait for busy=0 (operation complete)
4. Verify done=1 (success)
5. Set start=0 (clear done, ready for next)

## Building the Design

1. Navigate to the project directory:
   ```bash
   cd vivado_bram_sample
   ```

2. Run the build script:
   ```bash
   vivado -mode batch -source scripts/create_project.tcl
   ```

3. The script will create the Vivado project and generate the overlay file at:
   `export/bram_test_overlay.xsa`

## Running the Test

1. Copy the overlay file to PYNQ board:
   - From: `export/bram_test_overlay.xsa`
   - To: `/home/xilinx/jupyter_notebooks/` on PYNQ

2. Copy the test notebook:
   - From: `test/test_bram_overlay.ipynb`
   - To: `/home/xilinx/jupyter_notebooks/` on PYNQ

3. Open `test_bram_overlay.ipynb` in Jupyter on PYNQ

4. Run all cells to test functionality

## Test Sequence

The notebook performs these tests:
1. **Direct BRAM Access**: Verify Python read/write works
2. **Initial Values**: Write test data to addresses 0-3, verify write
3. **FSM Operation**: Run FSM to calculate and store sum
4. **Result Verification**: Check that sum is correctly stored at address 1023
5. **GPIO Control**: Verify start/done signal behavior

## Notes

- The TCL script uses relative paths, so run it from the project root directory
- The BRAM uses Xilinx Block Memory Generator IP with true dual-port configuration
- Port A is connected to AXI BRAM Controller for Python access
- Port B is connected to custom FSM with RISC-V-style interface
- The design includes comprehensive verification in the Jupyter notebook
