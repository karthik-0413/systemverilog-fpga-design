// Multicycle implementation of RISC-V (RV32I)
// Implements: lw, sw, add, sub, and, or, slt, addi, andi, ori, slti, beq, jal

`timescale 1ns/1ps

module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

  logic [31:0] ReadData;

  riscvmulti rvmulti(clk, reset, MemWrite, DataAdr,
                     WriteData, ReadData);
  mem mem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

module riscvmulti(input  logic        clk, reset,
                  output logic        MemWrite,
                  output logic [31:0] Adr, WriteData,
                  input  logic [31:0] ReadData);

  /***************************************************************************/
  // Control signals
  /***************************************************************************/

  logic        PCWrite, AdrSrc, IRWrite, RegWrite, Branch;
  logic [1:0]  ALUSrcA, ALUSrcB, ResultSrc, ALUOp, ImmSrc;
  logic [2:0]  ALUControl;
  logic        Zero, PCUpdate;

  /***************************************************************************/
  // Instruction decoding
  /***************************************************************************/

  logic [31:0] Instr;
  wire [6:0] op       = Instr[6:0];
  wire [2:0] funct3   = Instr[14:12];
  wire       funct7b5 = Instr[30];

  /***************************************************************************/
  // Step 1: FETCH - Read instruction from memory, PC = PC + 4
  //   Instr <= Mem[PC]
  //   OldPC <= PC
  //   ALUResult = PC + 4  (reuse ALU while it's free)
  //   PC <= ALUResult      (via ResultSrc = 10, PCUpdate)
  /***************************************************************************/

  logic [31:0] PC, OldPC;            // OldPC saved AfterStep1
  logic [31:0] AfterStep1_Instr;     // = Instr register (latched by IRWrite)

  // PC register (with enable = PCWrite)
  logic [31:0] Result;
  assign PCWrite = PCUpdate | (Branch & Zero);

  always_ff @(posedge clk, posedge reset)
    if (reset)        PC <= 32'b0;
    else if (PCWrite) PC <= Result;

  // Instruction register & OldPC (latched during Fetch when IRWrite = 1)
  always_ff @(posedge clk)
    if (IRWrite) begin
      Instr <= ReadData;   // AfterStep1: Instr holds the fetched instruction
      OldPC <= PC;         // AfterStep1: OldPC holds PC before increment
    end

  /***************************************************************************/
  // Step 2: DECODE - Read source operands from RF, extend immediate
  //   A <= rf[rs1]           (AfterStep2_A)
  //   B <= rf[rs2]           (AfterStep2_B / WriteData)
  //   ImmExt computed from Instr
  //   ALUOut <= OldPC + ImmExt  (precompute branch/jump target)
  /***************************************************************************/

  logic [31:0] AfterStep2_A;        // rs1 value, latched
  logic [31:0] AfterStep2_B;        // rs2 value, latched
  logic [31:0] ImmExt;              // sign-extended immediate

  // Register file
  logic [31:0] rf[31:0];

  always_ff @(posedge clk)
    if (RegWrite) rf[Instr[11:7]] <= Result;

  // Read register file (combinational)
  wire [31:0] RD1 = (Instr[19:15] != 0) ? rf[Instr[19:15]] : 32'b0;
  wire [31:0] RD2 = (Instr[24:20] != 0) ? rf[Instr[24:20]] : 32'b0;

  // Latch register outputs (AfterStep2)
  always_ff @(posedge clk) begin
    AfterStep2_A <= RD1;    // AfterStep2: A = rf[rs1]
    AfterStep2_B <= RD2;    // AfterStep2: B = rf[rs2]
  end

  assign WriteData = AfterStep2_B;  // rs2 data goes to memory WD

  // Immediate extension (combinational, based on ImmSrc from Instr Decoder)
  always_comb
    case(ImmSrc)
      2'b00:   ImmExt = {{20{Instr[31]}}, Instr[31:20]};                                // I-type
      2'b01:   ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};                   // S-type
      2'b10:   ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};   // B-type
      2'b11:   ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0}; // J-type
      default: ImmExt = 32'bx;
    endcase

  /***************************************************************************/
  // Step 3: EXECUTE / MEMORY ADDRESS / BRANCH / JUMP
  //   Depends on instruction type:
  //   - lw/sw (MemAdr):   ALUOut <= A + ImmExt     (memory address)
  //   - R-type (ExecuteR): ALUOut <= A op B
  //   - I-type (ExecuteI): ALUOut <= A op ImmExt
  //   - beq (BEQ):        ALUResult = A - B; if Zero, PC <= ALUOut
  //   - jal (JAL):        ALUResult = OldPC + 4; PC <= ALUOut (target)
  /***************************************************************************/

  logic [31:0] SrcA, SrcB, ALUResult;
  logic [31:0] AfterStep3_ALUOut;    // ALU result, latched

  // ALU input A mux (ALUSrcA)
  //   00 = PC        (used in Fetch: PC + 4)
  //   01 = OldPC     (used in Decode: OldPC + Imm, and JAL: OldPC + 4)
  //   10 = A         (used in Execute/MemAdr/BEQ: register rs1)
  always_comb
    case(ALUSrcA)
      2'b00:   SrcA = PC;
      2'b01:   SrcA = OldPC;
      2'b10:   SrcA = AfterStep2_A;
      default: SrcA = 32'bx;
    endcase

  // ALU input B mux (ALUSrcB)
  //   00 = B         (used in ExecuteR/BEQ: register rs2)
  //   01 = ImmExt    (used in Decode/MemAdr/ExecuteI: immediate)
  //   10 = 4         (used in Fetch: PC + 4, and JAL: OldPC + 4)
  always_comb
    case(ALUSrcB)
      2'b00:   SrcB = AfterStep2_B;
      2'b01:   SrcB = ImmExt;
      2'b10:   SrcB = 32'd4;
      default: SrcB = 32'bx;
    endcase

  // ALU
  logic [31:0] condinvb, sum;
  logic        v, isAddSub;

  assign condinvb = ALUControl[0] ? ~SrcB : SrcB;
  assign sum      = SrcA + condinvb + ALUControl[0];
  assign isAddSub = ~ALUControl[2] & ~ALUControl[1] | ~ALUControl[1] & ALUControl[0];
  assign v        = ~(ALUControl[0] ^ SrcA[31] ^ SrcB[31]) & (SrcA[31] ^ sum[31]) & isAddSub;
  assign Zero     = (ALUResult == 32'b0);

  always_comb
    case(ALUControl)
      3'b000:  ALUResult = sum;                   // add
      3'b001:  ALUResult = sum;                   // sub
      3'b010:  ALUResult = SrcA & SrcB;           // and
      3'b011:  ALUResult = SrcA | SrcB;           // or
      3'b100:  ALUResult = SrcA ^ SrcB;           // xor
      3'b101:  ALUResult = {31'b0, sum[31] ^ v};  // slt
      3'b110:  ALUResult = SrcA << SrcB[4:0];     // sll
      3'b111:  ALUResult = SrcA >> SrcB[4:0];     // srl
      default: ALUResult = 32'bx;
    endcase

  // ALUOut register (AfterStep3)
  always_ff @(posedge clk)
    AfterStep3_ALUOut <= ALUResult;

  /***************************************************************************/
  // Step 4: MEMORY READ / MEMORY WRITE
  //   - lw (MemRead):   Data <= Mem[ALUOut]    (AfterStep4_Data)
  //   - sw (MemWrite):  Mem[ALUOut] <= rs2
  //   - R/I-type:       (skip - go to ALUWB)
  /***************************************************************************/

  logic [31:0] AfterStep4_Data;      // memory read data, latched

  always_ff @(posedge clk)
    AfterStep4_Data <= ReadData;     // AfterStep4: Data = Mem[address]

  /***************************************************************************/
  // Step 5: WRITE BACK to register file
  //   - lw (MemWB):     rd <= Data           (ResultSrc = 01)
  //   - R/I-type (ALUWB): rd <= ALUOut       (ResultSrc = 00)
  //   - jal (ALUWB):    rd <= ALUOut (= PC+4) (ResultSrc = 00)
  /***************************************************************************/

  // Address mux: selects PC (Fetch) or ALUOut (MemRead/MemWrite)
  //   AdrSrc = 0: address = PC   (for instruction fetch)
  //   AdrSrc = 1: address = Result (= ALUOut, for data memory access)
  assign Adr = AdrSrc ? Result : PC;

  // Result mux (ResultSrc) - selects what gets written back
  //   00 = ALUOut      (R-type, I-type, JAL writeback)
  //   01 = Data        (lw writeback)
  //   10 = ALUResult   (direct ALU output, used in Fetch for PC+4)
  always_comb
    case(ResultSrc)
      2'b00:   Result = AfterStep3_ALUOut;
      2'b01:   Result = AfterStep4_Data;
      2'b10:   Result = ALUResult;
      default: Result = 32'bx;
    endcase

  /***************************************************************************/
  // Control Unit
  /***************************************************************************/

  // Main FSM
  mainfsm fsm(clk, reset, op,
              PCUpdate, AdrSrc, MemWrite, IRWrite,
              RegWrite, ALUSrcA, ALUSrcB,
              ALUOp, ResultSrc, Branch);

  // Instruction Decoder (ImmSrc from opcode)
  always_comb
    case(op)
      7'b0000011: ImmSrc = 2'b00; // lw  (I-type)
      7'b0010011: ImmSrc = 2'b00; // I-type ALU
      7'b0100011: ImmSrc = 2'b01; // sw  (S-type)
      7'b1100011: ImmSrc = 2'b10; // beq (B-type)
      7'b1101111: ImmSrc = 2'b11; // jal (J-type)
      default:    ImmSrc = 2'b00;
    endcase

  // ALU Decoder (same as single-cycle)
  wire RtypeSub = funct7b5 & op[5];

  always_comb
    case(ALUOp)
      2'b00:                ALUControl = 3'b000; // addition
      2'b01:                ALUControl = 3'b001; // subtraction
      default: case(funct3)
                 3'b000:  ALUControl = RtypeSub ? 3'b001 : 3'b000;
                 3'b010:  ALUControl = 3'b101; // slt
                 3'b110:  ALUControl = 3'b011; // or
                 3'b111:  ALUControl = 3'b010; // and
                 default: ALUControl = 3'bxxx;
               endcase
    endcase

endmodule

/******************************************************************************/
// Main FSM (see PDF slide 79 for the complete state diagram)
//
// States and what they do:
//   S0: FETCH     - Instr <= Mem[PC]; PC <= PC + 4
//   S1: DECODE    - Read registers; ALUOut <= OldPC + ImmExt (target address)
//   S2: MEMADR    - ALUOut <= rs1 + imm (memory address for lw/sw)
//   S3: MEMREAD   - Data <= Mem[ALUOut]
//   S4: MEMWB     - rd <= Data
//   S5: MEMWRITE  - Mem[ALUOut] <= rs2
//   S6: EXECUTER  - ALUOut <= rs1 op rs2
//   S7: ALUWB     - rd <= ALUOut
//   S8: EXECUTEI  - ALUOut <= rs1 op imm
//   S9: JAL       - PC <= ALUOut (target); ALUResult = OldPC + 4
//   S10: BEQ      - if (rs1 == rs2) PC <= ALUOut
/******************************************************************************/

module mainfsm(input  logic         clk,
               input  logic         reset,
               input  logic [6:0]   op,
               // Outputs in PDF order:
               output logic         PCUpdate,
               output logic         AdrSrc,
               output logic         MemWrite,
               output logic         IRWrite,
               output logic         RegWrite,
               output logic [1:0]   ALUSrcA,
               output logic [1:0]   ALUSrcB,
               output logic [1:0]   ALUOp,
               output logic [1:0]   ResultSrc,
               output logic         Branch);

  typedef enum logic [3:0] {
    FETCH     = 4'd0,   // S0
    DECODE    = 4'd1,   // S1
    MEMADR    = 4'd2,   // S2
    MEMREAD   = 4'd3,   // S3
    MEMWB     = 4'd4,   // S4
    MEMWRITE  = 4'd5,   // S5
    EXECUTER  = 4'd6,   // S6
    ALUWB     = 4'd7,   // S7
    EXECUTEI  = 4'd8,   // S8
    JAL       = 4'd9,   // S9
    BEQ       = 4'd10   // S10
  } statetype;

  statetype state, nextstate;

  // State register
  always_ff @(posedge clk, posedge reset)
    if (reset) state <= FETCH;
    else       state <= nextstate;

  // Next state logic (see PDF slide 79 FSM diagram)
  always_comb
    case(state)
      FETCH:    nextstate = DECODE;
      DECODE:   case(op)
                  7'b0000011: nextstate = MEMADR;    // lw
                  7'b0100011: nextstate = MEMADR;    // sw
                  7'b0110011: nextstate = EXECUTER;  // R-type
                  7'b0010011: nextstate = EXECUTEI;  // I-type ALU
                  7'b1101111: nextstate = JAL;       // jal
                  7'b1100011: nextstate = BEQ;       // beq
                  default:    nextstate = FETCH;
                endcase
      MEMADR:   case(op)
                  7'b0000011: nextstate = MEMREAD;   // lw
                  7'b0100011: nextstate = MEMWRITE;  // sw
                  default:    nextstate = FETCH;
                endcase
      MEMREAD:  nextstate = MEMWB;
      MEMWB:    nextstate = FETCH;
      MEMWRITE: nextstate = FETCH;
      EXECUTER: nextstate = ALUWB;
      EXECUTEI: nextstate = ALUWB;
      ALUWB:    nextstate = FETCH;
      JAL:      nextstate = ALUWB;
      BEQ:      nextstate = FETCH;
      default:  nextstate = FETCH;
    endcase

  // Output logic
  // Control word: PCUpdate_AdrSrc_MemWrite_IRWrite_RegWrite_ALUSrcA_ALUSrcB_ALUOp_ResultSrc_Branch
  logic [14:0] controls;

  always_comb
    case(state)
      //                    PCUpd_AdrSrc_MemWr_IRWr_RegWr_ALUSrcA_ALUSrcB_ALUOp_ResultSrc_Branch
      FETCH:    controls = 15'b1_0_0_1_0_00_10_00_10_0;  // PC+4, fetch instr
      DECODE:   controls = 15'b0_0_0_0_0_01_01_00_00_0;  // OldPC+Imm (target addr)
      MEMADR:   controls = 15'b0_0_0_0_0_10_01_00_00_0;  // rs1+imm (mem addr)
      MEMREAD:  controls = 15'b0_1_0_0_0_00_00_00_00_0;  // read Mem[ALUOut]
      MEMWB:    controls = 15'b0_0_0_0_1_00_00_00_01_0;  // rd <= Data
      MEMWRITE: controls = 15'b0_1_1_0_0_00_00_00_00_0;  // Mem[ALUOut] <= rs2
      EXECUTER: controls = 15'b0_0_0_0_0_10_00_10_00_0;  // rs1 op rs2
      EXECUTEI: controls = 15'b0_0_0_0_0_10_01_10_00_0;  // rs1 op imm
      ALUWB:    controls = 15'b0_0_0_0_1_00_00_00_00_0;  // rd <= ALUOut
      JAL:      controls = 15'b1_0_0_0_0_01_10_00_00_0;  // OldPC+4, PC<=ALUOut
      BEQ:      controls = 15'b0_0_0_0_0_10_00_01_00_1;  // rs1-rs2, branch
      default:  controls = 15'bx_x_x_x_x_xx_xx_xx_xx_x;
    endcase

  assign {PCUpdate, AdrSrc, MemWrite, IRWrite, RegWrite,
          ALUSrcA, ALUSrcB, ALUOp, ResultSrc, Branch} = controls;

endmodule

/******************************************************************************/
// Unified Memory (single memory for instructions and data)
/******************************************************************************/

module mem(input  logic        clk, we,
           input  logic [31:0] a, wd,
           output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("riscvtest.txt", RAM);

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule