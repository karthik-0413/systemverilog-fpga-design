// Multicycle implementation of RISC-V (RV32I)
// User-level Instruction Set Architecture V2.2 (May 7, 2017)
// Implements a subset of the base integer instructions:
//    lw, sw
//    add, sub, and, or, slt,
//    addi, andi, ori, slti
//    beq
//    jal
// Exceptions, traps, and interrupts not implemented
// little-endian memory

// 31 32-bit registers x1-x31, x0 hardwired to 0
//   Instruction  opcode    funct3    funct7
//   add          0110011   000       0000000
//   sub          0110011   000       0100000
//   and          0110011   111       0000000
//   or           0110011   110       0000000
//   slt          0110011   010       0000000
//   addi         0010011   000       immediate
//   andi         0010011   111       immediate
//   ori          0010011   110       immediate
//   slti         0010011   010       immediate
//   beq          1100011   000       immediate
//   lw	          0000011   010       immediate
//   sw           0100011   010       immediate
//   jal          1101111   immediate immediate

`timescale 1ns/1ps

module top(input  logic        clk, reset,
           output logic [31:0] WriteData, DataAdr,
           output logic        MemWrite);

  logic [31:0] ReadData;

  // instantiate processor and memories
  riscvmulti rvmulti(clk, reset, MemWrite, DataAdr,
                     WriteData, ReadData);
  mem mem(clk, MemWrite, DataAdr, WriteData, ReadData);
endmodule

module riscvmulti(input  logic        clk, reset,
                  output logic        MemWrite,
                  output logic [31:0] Adr, WriteData,
                  input  logic [31:0] ReadData);

  //***************************************************************************
  // Control signals
  //***************************************************************************

  logic       PCWrite, AdrSrc, IRWrite, RegWrite, Zero, PCUpdate, Branch;
  logic [1:0] ImmSrc, ALUSrcA, ALUSrcB, ResultSrc, ALUOp;
  logic [2:0] ALUControl;

  //***************************************************************************
  // Instruction Decoding
  //***************************************************************************
  logic [31:0] Instr;
  wire [6:0] op       = Instr[6:0];
  wire [2:0] funct3   = Instr[14:12];
  wire       funct7b5 = Instr[30];


  // ALU Decoder
  wire RtypeSub = funct7b5 & op[5]; // true for R-type sub

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

  // Instruction Decoder
  always_comb
    case(op)
      7'b0000011: ImmSrc = 2'b00; // Load Instructions
      7'b0010011: ImmSrc = 2'b00; // ALU Imm Instructions
      7'b0100011: ImmSrc = 2'b01; // Store Instructions
      7'b1100011: ImmSrc = 2'b10; // Control Flow Instructions
      7'b1101111: ImmSrc = 2'b11; // JAL Instructions
      default:    ImmSrc = 2'b00;
    endcase

 
  //***************************************************************************
  // STEP 1: Fetch Instruction
  //***************************************************************************

  logic [31:0] PC, OldPC, Result;
  
  // EN for the PC register
  assign PCWrite = PCUpdate || (Branch & Zero);

  // Select Signal for the First MUX
  assign Adr = AdrSrc ? Result : PC;

  // PC Register
  always_ff @(posedge clk, posedge reset)
    if (reset)        PC <= 32'b0;
    else if (PCWrite) PC <= Result;

  // Register right after the instr/data memory
  always_ff @(posedge clk)
    if (IRWrite) begin
      Instr <= ReadData;  // The fetched instruction
      OldPC <= PC;        // OldPC is PC before incrementing
    end


  //***************************************************************************
  // STEP 2: Decode
  //***************************************************************************

  logic [31:0] A, B, ImmExt;

  // Register file
  logic [31:0] rf[31:0];

  // The destination register
  always_ff @(posedge clk)
    if (RegWrite) rf[Instr[11:7]] <= Result;

  // Output of the register file
  always_ff @(posedge clk) begin
    A <= (Instr[19:15] != 0) ? rf[Instr[19:15]] : 32'b0;
    B <= (Instr[24:20] != 0) ? rf[Instr[24:20]] : 32'b0;
  end

  // WriteData back to the instr/data memory for sw instruction
  assign WriteData = B;

  // Immediate extension
  always_comb
    case(ImmSrc)
      2'b00:   ImmExt = {{20{Instr[31]}}, Instr[31:20]};                                // I-type
      2'b01:   ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};                   // S-type
      2'b10:   ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};   // B-type
      2'b11:   ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0}; // J-type
      default: ImmExt = 32'bx;
    endcase


  //***************************************************************************
  // STEP 3: Computations
  //***************************************************************************

  logic [31:0] SrcA, SrcB, ALUResult, ALUOut;

  // MUX for ALU input A (ALUSrcA)
  always_comb
    case(ALUSrcA)
      2'b00:   SrcA = PC;
      2'b01:   SrcA = OldPC;
      2'b10:   SrcA = A;
      default: SrcA = 32'bx;
    endcase

  // MUX for ALU input B (ALUSrcB)
  always_comb
    case(ALUSrcB)
      2'b00:   SrcB = B;
      2'b01:   SrcB = ImmExt;
      2'b10:   SrcB = 32'd4;
      default: SrcB = 32'bx;
    endcase

  // ALU
  logic [31:0] condinvb, sum;
  logic v, isAddSub;

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

  // ALUOut register
  always_ff @(posedge clk)
    ALUOut <= ALUResult;


  //***************************************************************************
  // STEP 4: Memory Read/Write & Write Back
  //***************************************************************************

  logic [31:0] MemData;

  always_ff @(posedge clk) begin
    MemData <= ReadData; // The data read from memory
  end

  always_comb begin
    case(ResultSrc)
      2'b00: Result = ALUOut;
      2'b01: Result = MemData;
      2'b10: Result = ALUResult;
      default: Result = 32'bx;
    endcase
  end


// Main FSM
  mainfsm fsm(clk, reset, op,
              ALUSrcA, ALUSrcB, ResultSrc, AdrSrc,
              IRWrite, PCUpdate, RegWrite, MemWrite,
              ALUOp, Branch);

endmodule

module mainfsm(input  logic         clk,
               input  logic         reset,
               input  logic [6:0]   op,
               output logic [1:0]   ALUSrcA, ALUSrcB,
               output logic [1:0]   ResultSrc,
               output logic         AdrSrc,
               output logic         IRWrite, PCUpdate,
               output logic         RegWrite, MemWrite,
               output logic [1:0]   ALUOp,
               output logic         Branch);

  typedef enum logic [3:0] {FETCH, DECODE, MEMADR, MEMREAD, MEMWB, MEMWRITE,
                            EXECUTER, EXECUTEI, ALUWB,
                            BEQ, JAL, UNKNOWN} statetype;

  statetype state, nextstate;
  logic [14:0] controls;

  // state register
  always @(posedge clk or posedge reset)
    if (reset) state <= FETCH;
    else state <= nextstate;

  // next state logic
  always_comb
    case(state)
      FETCH: 
        nextstate = DECODE;
      DECODE: case(op)
                7'b0000011: nextstate = MEMADR;
                7'b0100011: nextstate = MEMADR;
                7'b0110011: nextstate = EXECUTER;
                7'b0010011: nextstate = EXECUTEI;
                7'b1101111: nextstate = JAL;
                7'b1100011: nextstate = BEQ;
                default:    nextstate = FETCH;
              endcase
      MEMADR: case(op)
                7'b0000011: nextstate = MEMREAD;
                7'b0100011: nextstate = MEMWRITE; 
                default:    nextstate = FETCH;
              endcase
      MEMREAD:  nextstate = MEMWB;
      MEMWB:    nextstate = FETCH;
      MEMWRITE: nextstate = FETCH;
      ALUWB:    nextstate = FETCH;
      EXECUTER: nextstate = ALUWB;
      EXECUTEI: nextstate = ALUWB;
      JAL:      nextstate = ALUWB;
      BEQ:      nextstate = FETCH;
      default:                   nextstate = FETCH;
    endcase

  // state-dependent output logic
  // PCUpdate_AdrSrc_MemWrite_IRWrite_RegWrite_ALUSrcA_ALUSrcB_ALUOp_ResultSrc_Branch
  // MemWrite, IRWrite, RegWrite, PCUpdate, and Branch cannot be x, since they have to be held down 

  assign {PCUpdate, AdrSrc, MemWrite, IRWrite, RegWrite,
          ALUSrcA, ALUSrcB, ALUOp, ResultSrc, Branch} = controls;
  
  always_comb
    case(state)
      FETCH:    controls = 15'b1_0_0_1_0_00_10_00_10_0; // AdrSrc=0, IRWrite, ALUSrcA=00, ALUSrcB=10, ALUOp=00, ResultSrc=10, PCUpdate
      DECODE:   controls = 15'b0_x_0_0_0_01_01_00_xx_0; // ALUSrcA=01, ALUSrcB=01, ALUOp=00
      MEMADR:   controls = 15'b0_x_0_0_0_10_01_00_xx_0; // ALUSrcA=10, ALUSrcB=01, ALUOp=00
      MEMREAD:  controls = 15'b0_1_0_0_0_xx_xx_xx_00_0; // ResultSrc=00, AdrSrc=1
      MEMWB:    controls = 15'b0_x_0_0_1_xx_xx_xx_01_0; // ResultSrc=01, RegWrite
      MEMWRITE: controls = 15'b0_1_1_0_0_xx_xx_xx_00_0; // ResultSrc=00, AdrSrc=1, MemWrite
      EXECUTER: controls = 15'b0_x_0_0_0_10_00_10_xx_0; // ALUSrcA=10, ALUSrcB=00, ALUOp=10
      EXECUTEI: controls = 15'b0_x_0_0_0_10_01_10_xx_0; // ALUSrcA=10, ALUSrcB=01, ALUOp=10
      ALUWB:    controls = 15'b0_x_0_0_1_xx_xx_xx_00_0; // ResultSrc=00, RegWrite
      JAL:      controls = 15'b1_x_0_0_0_01_10_00_00_0; // ALUSrcA=01, ALUSrcB=10, ALUOp=00, ResultSrc=00, PCUpdate
      BEQ:      controls = 15'b0_x_0_0_0_10_00_01_00_1; // ALUSrcA=10, ALUSrcB=00, ALUOp=01, ResultSrc=00, Branch
      default:  controls = 15'bx_x_x_x_x_xx_xx_xx_xx_x; // All don't cares
    endcase

endmodule

module mem(input  logic        clk, we,
           input  logic [31:0] a, wd,
           output logic [31:0] rd);

  logic [31:0] RAM[63:0];

  initial
      $readmemh("riscvtest.txt",RAM);

  assign rd = RAM[a[31:2]]; // word aligned

  always_ff @(posedge clk)
    if (we) RAM[a[31:2]] <= wd;
endmodule