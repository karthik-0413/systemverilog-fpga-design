# SystemVerilog FPGA Design

Advanced FPGA digital design projects using SystemVerilog, RTL design, Vivado, Vitis HLS, and PYNQ-based Jupyter Notebook workflows for hardware-software co-design and FPGA interaction.

## Course Topics

- RTL Design using SystemVerilog
- FPGA synthesis and implementation
- Verification and testbench development
- FIR filter architecture and DSP design
- RISC-V processor design
- Multi-cycle CPU datapath/control
- Pipeline optimization and performance improvement
- Memory-mapped peripherals using APB
- GPIO and Timer peripheral integration
- High-Level Synthesis (HLS) using Vitis HLS
- Hardware-software co-design using PYNQ (Jupyter Notebook + FPGA interaction)

---

## Execution Environment

All labs were developed and tested on a Zynq-based FPGA platform using the PYNQ framework. Jupyter notebooks were used to interface Python running on the Processing System (PS) with custom hardware accelerators in the Programmable Logic (PL), enabling real-time control, testing, and validation of FPGA designs across all labs.

---

## Labs

### Lab 1 — Arithmetic Logic Unit (ALU)

Designed and verified a parameterized ALU in SystemVerilog supporting arithmetic, logical, comparison, and shift operations with simulation-based validation. The design was tested and controlled through PYNQ Jupyter notebooks for interactive verification on FPGA hardware.

---

### Lab 2 — 64-Tap FIR Filter

Implemented a 64-tap FIR filter architecture for digital signal processing applications, focusing on datapath design, coefficient handling, and timing-aware RTL development. Python notebooks in PYNQ were used to stream inputs and validate hardware output in real time.

---

### Lab 3 — RISC-V CPU (Single-Cycle and Multi-Cycle)

Designed a RV32I-compatible RISC-V processor supporting both single-cycle and multi-cycle execution models, including datapath, control logic, instruction decoding, and memory interface design. Execution and debugging were performed using PYNQ-based interaction with the FPGA system.

---

### Lab 4 — Optimized RISC-V CPU

Improved processor performance by redesigning execution flow so most instructions complete in approximately two cycles, reducing latency while maintaining correctness. PYNQ notebooks were used to observe instruction execution behavior and validate performance improvements.

---

### Lab 5 — RV32I + APB Peripherals

Extended the RISC-V processor with APB-based GPIO and Timer peripherals using memory-mapped I/O, enabling embedded system functionality and peripheral communication. Python interfaces in PYNQ controlled and tested peripheral behavior in real time.

---

### Lab 6 — Vitis HLS Design

Developed hardware modules using HLS in Vitis HLS, converting high-level C/C++ descriptions into synthesizable FPGA hardware and analyzing performance/resource tradeoffs. Generated accelerators were deployed on FPGA and controlled via PYNQ Jupyter notebooks.

---

## Tools Used

- SystemVerilog
- Vivado
- Vitis HLS
- Xilinx FPGA development flow
- RTL simulation and verification tools
- PYNQ (Python-based Jupyter Notebook FPGA interaction framework)

---

## Focus Areas

This repository emphasizes practical hardware design for FPGA systems, processor architecture, embedded systems integration, and accelerator-oriented digital design. It demonstrates full hardware-software co-design workflows using RTL, HLS, and Python-based FPGA control via PYNQ on a Zynq SoC platform.
