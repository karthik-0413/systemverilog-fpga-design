# RV32I Multi-Cycle Processor Architecture

A brief guide to understanding the multi-cycle RV32I processor design.

## Architecture Overview

The processor is a **multi-cycle design** that executes each instruction over 2-4 clock cycles depending on whether the instruction accesses memory.

### Key Characteristics

- **Clock cycles per instruction**: 2-4 cycles
  - Non-memory instructions: 2 cycles (EXECUTE + WAIT_INSTR)
  - Memory instructions: 4 cycles (EXECUTE + WAIT_MEM + FETCH_INSTR + WAIT_INSTR)
- **Memory**: Unified 1KB synchronous BRAM for instructions and data
- **Instruction set**: Full RV32I base integer instructions
- **Register file**: 32 x 32-bit registers (x0-x31)

## Finite State Machine (FSM)

The processor operates using a 4-state FSM:

```
┌──────────────────────────────────────────────────────────┐
│  FETCH_INSTR                                             │
│  - Set mem_addr = PC                                     │
│  - Request instruction fetch from BRAM                   │
│  - Transition: WAIT_INSTR                                │
└─────────────────┬──────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│  WAIT_INSTR                                              │
│  - Wait for instruction fetch to complete                │
│  - When mem_busy = 0:                                    │
│    * Latch instruction into instR                        │
│    * Read register values                                │
│    * Transition: EXECUTE                                 │
└─────────────────┬──────────────────────────────────────--┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────┐
│  EXECUTE                                                 │
│  - Decode instruction from instR                         │
│  - Execute ALU operation                                 │
│  - Compute memory address (if load/store)                │
│  - Update PC for branch/jump                             │
│  - Start memory operation (if load/store)                │
│  - If non-memory instruction:                            │
│    * Write result to register                            │
│    * Transition: WAIT_INSTR (back to fetch next)        │
│  - If memory instruction (load/store):                   │
│    * DON'T write register yet                            │
│    * Transition: WAIT_MEM                                │
└─────────────────┬──────────────────────────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    (non-memory)      (memory)
         │                 │
    WAIT_INSTR          WAIT_MEM
         │                 │
         │                 ▼
         │  ┌──────────────────────────────────────────────────────┐
         │  │  WAIT_MEM                                            │
         │  │  - Wait for memory operation to complete             │
         │  │  - When mem_busy = 0:                               │
         │  │    * Latch load data (if load)                      │
         │  │    * Write result to register                        │
         │  │    * Transition: FETCH_INSTR (next instruction)     │
         │  └──────────────────────────────────────────────────────┘
         │                 │
         └────────┬────────┘
                  │
                  ▼
           (Next instruction)
```

### State Descriptions

#### FETCH_INSTR (Fetch Instruction)
- **Duration**: 1 cycle minimum
- **Actions**:
  - Set `mem_addr = PC` to fetch current instruction
  - Set `mem_ren = 1` to read from memory
  - Set `mem_wmask = 0` (no write)
- **Transition**: WAIT_INSTR

#### WAIT_INSTR (Wait for Instruction)
- **Duration**: Until `mem_busy = 0`
- **Actions**:
  - Wait for instruction to be fetched from BRAM
  - When ready (`mem_busy = 0`):
    - Enable register file read (`rdR_en = 1`)
    - Latch instruction (`instR_en = 1`)
    - Next cycle will have instruction available
- **Transition**: EXECUTE

#### EXECUTE (Execute Instruction)
- **Duration**: 1 cycle
- **Actions**:
  - **Decode**: Extract opcode, rd, rs1, rs2 from `instR`
  - **ALU**: Compute result (arithmetic, logic, shift)
  - **Address**: Compute memory address = rs1 + immediate (for load/store)
  - **Branch/Jump**: Compute next PC
  - **Register Write** (non-memory only): `writeBack = 1` if not load/store
  - **Memory Setup** (load/store): Set address and control signals
- **Transition**:
  - If non-memory instruction: WAIT_INSTR (continue to next)
  - If memory instruction: WAIT_MEM (wait for memory)
  - Branch/jump: PC is updated immediately

#### WAIT_MEM (Wait for Memory)
- **Duration**: Until `mem_busy = 0`
- **Actions**:
  - Wait for load/store operation to complete
  - When ready (`mem_busy = 0`):
    - For load: Prepare loaded data for register write
    - Set `writeBack = 1` to write result to register
- **Transition**: FETCH_INSTR (next instruction)

---

## Top-Level Module: RV32I

### Module Definition

```verilog
module RV32I(
   input         clk,
   output logic [31:0] mem_addr,
   output logic [31:0] mem_wdata,
   output logic  [3:0] mem_wmask,
   input  logic [31:0] mem_rdata,
   output logic        mem_ren,
   input  logic         mem_busy,
   input  logic         reset
);
```

### Signal Descriptions

#### Clock & Reset
- **clk**: Clock signal (all state changes occur on rising edge)
- **reset**: Active-high reset (set to 0 to reset, must be released before use)

#### Memory Address Bus
- **mem_addr[31:0]**: Address for memory read/write
  - Bits [31:2]: Word address (byte address >> 2)
  - Bits [1:0]: Byte offset (for unaligned access, future extension)
  - During FETCH: PC (instruction address)
  - During LOAD/STORE: rs1 + immediate (data address)

#### Memory Write Data
- **mem_wdata[31:0]**: Data to write to memory
  - During STORE: rs2 value (or shifted for byte store)
  - Used only when `mem_wmask != 0`

#### Memory Write Mask
- **mem_wmask[3:0]**: Byte enable signals
  - Bit 0: Write byte [7:0]
  - Bit 1: Write byte [15:8]
  - Bit 2: Write byte [23:16]
  - Bit 3: Write byte [31:24]
  - `4'b1111`: Write full word
  - `4'b0000`: No write (read operation)

#### Memory Read Data
- **mem_rdata[31:0]**: Data read from memory
  - Updated combinatorially by BRAM
  - Contains current instruction when fetching
  - Contains loaded data when reading

#### Memory Read Enable
- **mem_ren**: Read request signal
  - Set to 1 to initiate a read
  - Used during FETCH_INSTR state
  - BRAM ignores this (synchronous read), but included for interface

#### Memory Busy Signal
- **mem_busy**: Indicates memory is busy
  - 0: Memory operation complete, data valid
  - 1: Memory operation in progress
  - For this lab, BRAM always sets `mem_busy = 0` (instant access)
  - Useful for future extensions with slow memory

---

## BRAM Module

### Module Definition

```verilog
module bram(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  wmask,
    input  logic        we,
    output logic [31:0] rdata
);
```

### Behavior

- **Combinatorial Read**: `rdata = mem[addr[31:2]]` (instant)
  - Data appears on same cycle as address is set
- **Synchronous Write**: Occurs on rising edge of clock
  - Data written from `wdata` to `mem[addr[31:2]]`
  - Only bytes with `wmask[i] = 1` are written
- **Memory Size**: 256 words (1024 bytes) at addresses 0x0 to 0x3FC
- **Initialization**: Loads from `riscvtest.txt` on startup

### Example Timing

```
Cycle N:   mem_addr = 0x100, mem_wmask = 4'b1111, mem_wdata = 0x12345678
Cycle N:   rdata = mem[0x100] (combinatorial, old value)
Cycle N+1: mem[0x100] = 0x12345678 (written at rising edge)
Cycle N+1: rdata = mem[0x100] (now has new value)
```

---

## Instruction Execution Examples

### Example 1: Non-Memory Instruction (ADD)

**Instruction**: `add x2, x3, x4` (add x3 + x4, store in x2)

```
Cycle 0: FETCH_INSTR
  - mem_addr = PC (e.g., 0x0)
  - mem_ren = 1
  - State: FETCH_INSTR → WAIT_INSTR

Cycle 1: WAIT_INSTR
  - mem_rdata = instruction (ADD instruction arrives)
  - rdR_en = 1 (read x3, x4)
  - instR_en = 1 (latch instruction)
  - State: WAIT_INSTR → EXECUTE

Cycle 2: EXECUTE
  - instR = ADD instruction (decoded)
  - rd1R = x3 value, rd2R = x4 value (from register file)
  - ALU: aluOut = rd1R + rd2R
  - writeBack = 1 (not a memory instruction)
  - At end of cycle: registerFile[2] ← aluOut
  - mem_addr = PC_next (for next fetch)
  - State: EXECUTE → WAIT_INSTR

Cycle 3: WAIT_INSTR (next instruction)
  - (repeats for next instruction)
```

**Total**: 3 cycles (FETCH + WAIT + EXECUTE, then immediately start WAIT for next)

---

### Example 2: Load Instruction (LW)

**Instruction**: `lw x2, 8(x3)` (load from address x3+8 into x2)

```
Cycle 0: FETCH_INSTR
  - mem_addr = PC
  - mem_ren = 1
  - State: FETCH_INSTR → WAIT_INSTR

Cycle 1: WAIT_INSTR
  - mem_rdata = instruction (LW instruction)
  - rdR_en = 1 (read x3)
  - instR_en = 1 (latch instruction)
  - State: WAIT_INSTR → EXECUTE

Cycle 2: EXECUTE
  - instR = LW instruction (decoded)
  - rd1R = x3 value (from register file)
  - aluOut = rd1R + 8 (compute load address)
  - mem_addr = aluOut (address to load from)
  - mem_ren = 1
  - writeBack = 0 (DON'T write yet; wait for data)
  - State: EXECUTE → WAIT_MEM
  - BRAM: rdata = mem[aluOut] (starts fetching)

Cycle 3: WAIT_MEM
  - mem_busy = 0 (data ready in BRAM)
  - mem_rdata = data from address (available combinatorially)
  - writeBack = 1
  - At end of cycle: registerFile[2] ← mem_rdata
  - mem_addr = PC_next (for next fetch)
  - mem_ren = 1 (start next fetch)
  - State: WAIT_MEM → FETCH_INSTR

Cycle 4: FETCH_INSTR (next instruction)
  - (repeats for next instruction)
```

**Total**: 4 cycles (FETCH + WAIT + EXECUTE + WAIT_MEM, then FETCH next)

---

### Example 3: Store Instruction (SW)

**Instruction**: `sw x2, 8(x3)` (store x2 to address x3+8)

```
Cycle 0: FETCH_INSTR
  - mem_addr = PC
  - mem_ren = 1
  - State: FETCH_INSTR → WAIT_INSTR

Cycle 1: WAIT_INSTR
  - mem_rdata = instruction (SW instruction)
  - rdR_en = 1 (read x3, x2)
  - instR_en = 1 (latch instruction)
  - State: WAIT_INSTR → EXECUTE

Cycle 2: EXECUTE
  - instR = SW instruction (decoded)
  - rd1R = x3, rd2R = x2 (from register file)
  - aluOut = rd1R + 8 (compute store address)
  - mem_addr = aluOut (address to write to)
  - mem_wdata = rd2R (data to write)
  - mem_wmask = 4'b1111 (write full word)
  - writeBack = 0 (stores don't write registers)
  - At end of cycle: BRAM writes mem[aluOut] ← rd2R
  - State: EXECUTE → WAIT_MEM

Cycle 3: WAIT_MEM
  - mem_busy = 0 (write complete)
  - writeBack = 0 (don't write anything)
  - mem_addr = PC_next (for next fetch)
  - mem_ren = 1 (start next fetch)
  - State: WAIT_MEM → FETCH_INSTR

Cycle 4: FETCH_INSTR (next instruction)
  - (repeats for next instruction)
```

**Total**: 4 cycles (FETCH + WAIT + EXECUTE + WAIT_MEM)

---

### Example 4: Branch Instruction (BEQ)

**Instruction**: `beq x2, x3, label` (branch if x2 == x3)

```
Cycle 0: FETCH_INSTR
  - mem_addr = PC
  - mem_ren = 1
  - State: FETCH_INSTR → WAIT_INSTR

Cycle 1: WAIT_INSTR
  - mem_rdata = instruction (BEQ instruction)
  - rdR_en = 1 (read x2, x3)
  - instR_en = 1 (latch instruction)
  - State: WAIT_INSTR → EXECUTE

Cycle 2: EXECUTE
  - instR = BEQ instruction (decoded)
  - rd1R = x2, rd2R = x3 (from register file)
  - ALU: Compare rd1R == rd2R
  - If equal:
    * PC_next = PC + Bimm (branch offset)
  - Else:
    * PC_next = PC + 4 (continue)
  - At end of cycle: PC ← PC_next
  - mem_addr = PC_next (for next fetch)
  - writeBack = 0 (branches don't write registers)
  - State: EXECUTE → WAIT_INSTR

Cycle 3: WAIT_INSTR (next instruction, possibly at branch target)
  - (repeats)
```

**Total**: 3 cycles (FETCH + WAIT + EXECUTE), with PC updated for branch

---

## Key Implementation Points

### 1. Register Writeback Timing

**Critical**: Register writes must happen at the right time:

- **ALU instructions**: Write in EXECUTE state (then go to WAIT_INSTR)
- **Load instructions**: Write in WAIT_MEM state (after data is ready)
- **Store instructions**: Never write (memory instruction, data goes OUT)
- **Branch/Jump**: Never write to register (unless link register JAL/JALR)
- **JAL/JALR**: Write PC+4 in EXECUTE state

### 2. Memory Address Calculation

All load/store addresses use the same formula:
```
address = rs1 + immediate
```

Where:
- rs1 comes from register file (`rd1R`)
- immediate is extracted from instruction:
  - I-type (load, JALR): `{{21{instR[31]}}, instR[30:20]}`
  - S-type (store): `{{21{instR[31]}}, instR[30:25], instR[11:7]}`

### 3. Next PC Computation

- **Normal**: `PC_next = PC + 4`
- **Branch taken**: `PC_next = PC + Bimm`
- **JAL**: `PC_next = PC + Jimm`
- **JALR**: `PC_next = rs1 + Iimm` (computed in ALU)

Updated in EXECUTE state.

### 4. Immediate Format Extraction

Different instruction formats use different bit ranges:

- **I-type**: `{{21{instR[31]}}, instR[30:20]}`
- **S-type**: `{{21{instR[31]}}, instR[30:25], instR[11:7]}`
- **B-type**: `{{20{instR[31]}}, instR[7], instR[30:25], instR[11:8], 1'b0}`
- **U-type**: `{instR[31:12], 12'b0}`
- **J-type**: `{{12{instR[31]}}, instR[19:12], instR[20], instR[30:21], 1'b0}`

### 5. Write Mask Generation (Byte Granularity)

For future byte/halfword access:

- **Word write** (`SW`): `4'b1111`
- **Halfword write** (upper/lower): `4'b0011` or `4'b1100`
- **Byte write** (all positions): `4'b0001`, `4'b0010`, `4'b0100`, `4'b1000`

Currently, only word access is required.

---

## Common Pitfalls to Avoid

1. **Double-writing registers**: Register write must happen ONCE
   - For loads: Only in WAIT_MEM
   - For ALU: Only in EXECUTE
   - Not in both states

2. **Wrong immediate format**: Each instruction type uses different bits
   - Check the RISC-V spec for each format
   - Sign-extend correctly

3. **Branch offset calculation**: Remember to add PC first, then offset
   - `PC + Bimm`, not just `Bimm`

4. **State machine deadlock**: Make sure transitions always happen
   - Check that next_state is defined for all states
   - Ensure mem_busy is properly handled

5. **Register file timing**: Reads are combinatorial, writes are sequential
   - Read: `rd1R = registerFile[rs1Id]` (immediate)
   - Write: `registerFile[rdId] <= writeBackData` (on clock edge)

---

## Testing Checklist

- [ ] FETCH_INSTR → WAIT_INSTR → EXECUTE sequence correct
- [ ] Non-memory instructions reach WAIT_INSTR next
- [ ] Memory instructions reach WAIT_MEM next
- [ ] Register writes happen at correct time (not double-written)
- [ ] Load data is available after WAIT_MEM
- [ ] Branch/jump updates PC correctly
- [ ] All ALU operations produce correct results
- [ ] Memory addresses computed correctly
- [ ] Write mask correct for word stores

---

## Summary Table

| State | Duration | Key Actions | Next State |
|-------|----------|-------------|-----------|
| FETCH_INSTR | 1 cycle | Set addr=PC, mem_ren=1 | WAIT_INSTR |
| WAIT_INSTR | 1 cycle | Latch instr, read regs | EXECUTE |
| EXECUTE | 1 cycle | Decode, ALU, (write if not mem) | WAIT_INSTR or WAIT_MEM |
| WAIT_MEM | 1 cycle | (write if load) | FETCH_INSTR |

**Total per instruction**: 3-4 cycles

---

**Ready to implement?** Start with the skeleton in `riscv_fast/rtl/riscv_fast.sv` and follow the comments!
