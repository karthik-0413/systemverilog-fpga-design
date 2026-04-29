# BRAM AXI Test Design for PYNQ-Z1

## Quick Start

```bash
cd vivado_bram_sample
vivado -mode batch -source scripts/create_project.tcl
```

## Project Structure

```
vivado_bram_sample/
├── src/                    # RTL source files
│   ├── bram_test_fsm.sv   # FSM module
│   └── bram_wrapper.v      # Block design wrapper
├── scripts/                # Build scripts
│   └── create_project.tcl  # Vivado project creation script
├── docs/                   # Documentation
│   └── README.md          # Detailed documentation
├── test/                   # Test files
│   └── test_bram_overlay.ipynb # PYNQ test notebook
├── export/                # Generated files (created by build)
│   └── bram_test_overlay.xsa   # Generated overlay
└── README.md              # This file
```

## Overview

This project creates a complete Vivado design and PYNQ test for a dual-port BRAM with AXI access and FSM control.

## Build Instructions

1. Navigate to the project directory and run:
   ```bash
   vivado -mode batch -source scripts/create_project.tcl
   ```

2. Copy generated files to PYNQ:
   - `export/bram_test_overlay.xsa` → `/home/xilinx/jupyter_notebooks/`
   - `test/test_bram_overlay.ipynb` → `/home/xilinx/jupyter_notebooks/`

3. Run the notebook on PYNQ to test functionality.

## Detailed Documentation

See `docs/README.md` for complete documentation including:
- Design architecture
- GPIO control sequence
- Test procedures
- Memory map
- Expected results
