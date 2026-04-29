`timescale 1ns/1ps

// RISC-V single-cycle processor (RV32I subset)
// Implements: lw, sw, add, sub, and, or, slt, andi, ori, slti, beq (**** IMPLEMENT addi & jal ****)

module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

  logic [31:0] PC, Instr, ReadData;

  riscvsingle rvsingle(clk, reset, PC, Instr, MemWrite, DataAdr, WriteData, ReadData);
  imem imem(PC, Instr);
  dmem dmem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

module riscvsingle(input  logic        clk, reset,
                   output logic [31:0] PC,
                   input  logic [31:0] Instr,
                   output logic        MemWrite,
                   output logic [31:0] ALUResult, WriteData,
                   input  logic [31:0] ReadData);

  /***************************************************************************/
  // Instruction decoding.
  /***************************************************************************/

  wire [6:0] op       = Instr[6:0];
  wire [2:0] funct3   = Instr[14:12];
  wire       funct7b5 = Instr[30];

  /***************************************************************************/
  // Main decoder -- control signals from opcode.
  /***************************************************************************/

  logic [1:0] ResultSrc, ImmSrc, ALUOp;
  logic       ALUSrc, RegWrite, Jump, Branch;
  logic [10:0] controls;

  assign {RegWrite, ImmSrc, ALUSrc, MemWrite,
          ResultSrc, Branch, ALUOp, Jump} = controls;

  always_comb
    case(op)
    // RegWrite_ImmSrc_ALUSrc_MemWrite_ResultSrc_Branch_ALUOp_Jump
      7'b0000011: controls = 11'b1_00_1_0_01_0_00_0; // lw
      7'b0100011: controls = 11'b0_01_1_1_00_0_00_0; // sw
      7'b0110011: controls = 11'b1_xx_0_0_00_0_10_0; // R-type
      7'b1100011: controls = 11'b0_10_0_0_00_1_01_0; // beq
      7'b0010011: controls = 11'b1_00_1_0_00_0_10_0; // addi
      7'b1101111: controls = 11'b1_11_x_0_10_0_xx_1; // jal
      default:    controls = 11'bx_xx_x_x_xx_x_xx_x;
    endcase

  /***************************************************************************/
  // ALU decoder -- ALU operation from funct3/funct7.
  /***************************************************************************/

  logic [2:0] ALUControl;
  wire        RtypeSub = funct7b5 & op[5]; // true for R-type sub

  always_comb
    case(ALUOp)
      2'b00:                ALUControl = 3'b000; // addition (lw/sw)
      2'b01:                ALUControl = 3'b001; // subtraction (beq)
      default: case(funct3)
                 3'b000:  ALUControl = RtypeSub ? 3'b001 : 3'b000; // sub / add (Same functionality for addi)
                 3'b010:  ALUControl = 3'b101; // slt, slti
                 3'b110:  ALUControl = 3'b011; // or, ori
                 3'b111:  ALUControl = 3'b010; // and, andi
                 default: ALUControl = 3'bxxx;
               endcase
    endcase

  /***************************************************************************/
  // Immediate extension.
  /***************************************************************************/

  logic [31:0] ImmExt;

  always_comb
    case(ImmSrc)
      2'b00:   ImmExt = {{20{Instr[31]}}, Instr[31:20]};                               // I-type
      2'b01:   ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};                  // S-type
      2'b10:   ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};  // B-type
      2'b11:   ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[11], Instr[30:21], 1'b0};  // J-type
      default: ImmExt = 32'bx;
    endcase

  /***************************************************************************/
  // Register file.
  /***************************************************************************/

  logic [31:0] rf[31:0];
  logic [31:0] SrcA, Result;

  always_ff @(posedge clk)
    if (RegWrite) rf[Instr[11:7]] <= Result;

  assign SrcA      = (Instr[19:15] != 0) ? rf[Instr[19:15]] : 32'b0;
  assign WriteData = (Instr[24:20] != 0) ? rf[Instr[24:20]] : 32'b0;

  /***************************************************************************/
  // ALU.
  /***************************************************************************/

  logic [31:0] SrcB, condinvb, sum;
  logic        Zero, v, isAddSub;

  assign SrcB     = ALUSrc ? ImmExt : WriteData;
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

  /***************************************************************************/
  // PC and branch logic.
  /***************************************************************************/

  logic [31:0] PCNext, PCPlus4, PCTarget;

  assign PCPlus4  = PC + 32'd4;
  assign PCTarget = PC + ImmExt;
  // assign PCNext   = (Branch & Zero) ? PCTarget : PCPlus4;
  assign PCNext   = (Jump || (Branch & Zero)) ? PCTarget : PCPlus4;

  always_ff @(posedge clk, posedge reset)
    if (reset) PC <= 32'b0;
    else       PC <= PCNext;

  /***************************************************************************/
  // Result writeback mux.
  /***************************************************************************/

  // assign Result = ResultSrc[0] ? ReadData : ALUResult;

  always_comb
    case(ResultSrc)
      2'b00: Result = ALUResult;
      2'b01: Result = ReadData;
      2'b10: Result = PCPlus4;
      2'b11: Result = 0;
    endcase

endmodule

module imem(input  logic [31:0] a,
            output logic [31:0] rd);
  logic [31:0] RAM[63:0];
  initial $readmemh("riscvtest.txt", RAM);
  assign rd = RAM[a[31:2]];
endmodule

module dmem(input  logic        clk, we,
            input  logic [31:0] a, wd,
            output logic [31:0] rd);
  logic [31:0] RAM[63:0];
  assign rd = RAM[a[31:2]];
  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule
