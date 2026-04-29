`timescale 1ns/1ps

module RV32I(
   input         clk,

   output logic [31:0] mem_addr,  // address bus
   output logic [31:0] mem_wdata, // data to be written
   output logic  [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input  logic [31:0] mem_rdata, // input lines for both data and instr
   output logic        mem_ren, // active to initiate memory read (used by IO)
   input  logic        mem_busy, // asserted if memory is busy with read or write

   input  logic        reset      // set to 0 to reset the processor
);

   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 24;

   // Forward declarations for register file control
   logic [31:0]         instR;        // Latched instruction. Note that bits 0 and 1 ar
   logic instR_en;

/***************************************************************************/
// The register file.
/***************************************************************************/
logic [31:0]         rd1R, rd2R, writeBackData;
logic writeBack, rdR_en;
logic [31:0]         registerFile [31:0];

   // Register identifiers
   logic [4:0] rs1Id, rs2Id, rdId;
   assign rdId = instR[11:7];
   assign rs1Id = mem_rdata[19:15];
   assign rs2Id = mem_rdata[24:20];

   always @(posedge clk) begin
      // Register file reads registers (controlled by rdR_en)
      if (rdR_en) begin
         // x0 is hardwired to 0 in RISC-V ABI
         rd1R <= (rs1Id == 0) ? 32'b0 : registerFile[rs1Id];
         rd2R <= (rs2Id == 0) ? 32'b0 : registerFile[rs2Id];
   end
      
   // Register file write
   if (writeBack)
      if (rdId != 0)
      registerFile[rdId] <= writeBackData;
end



 /***************************************************************************/
 // Instruction decoding.
 /***************************************************************************/

 // The ALU function decide in 1-hot (reduces LUT count)
 // It is used as follows: funct3Is[val] <=> funct3 == val
 (* onehot *)
 logic [7:0] funct3Is;
 assign funct3Is = 8'b00000001 << instR[14:12];

 // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
   logic [31:0] Uimm, Iimm, Simm, Bimm, Jimm;
   assign Uimm = {instR[31:12], 12'b0};
   assign Iimm = {{20{instR[31]}}, instR[31:20]};
   assign Simm = {{20{instR[31]}}, instR[31:25], instR[11:7]};
   assign Bimm = {{20{instR[31]}}, instR[7], instR[30:25], instR[11:8], 1'b0};
   assign Jimm = {{12{instR[31]}}, instR[19:12], instR[20], instR[30:21], 1'b0};
   //
   // 
   //

   // Base RISC-V (RV32I) has only 10 different instructions (Look at opcode)
   logic isLoad, isALUimm, isAUIPC, isStore, isALUreg, isLUI, isBranch, isJALR, isJAL, isSYSTEM, isALU;
   //

   assign isALUimm   = (instR[6:0] == 7'b0010011) ? 1 : 0; // ALUimm instructions
   assign isALUreg   = (instR[6:0] == 7'b0110011) ? 1 : 0; // ALUreg instructions
   assign isALU      = (isALUimm || isALUreg)     ? 1 : 0;    // ALU instructions
   assign isLoad     = (instR[6:0] == 7'b0000011) ? 1 : 0;   // Load instructions
   assign isStore    = (instR[6:0] == 7'b0100011) ? 1 : 0;  // Store instructions
   assign isBranch   = (instR[6:0] == 7'b1100011) ? 1 : 0; // Branch instructions
   assign isJAL      = (instR[6:0] == 7'b1101111) ? 1 : 0;    // JAL instructions
   assign isJALR     = (instR[6:0] == 7'b1100111) ? 1 : 0;   // JALR instructions
   assign isLUI      = (instR[6:0] == 7'b0110111) ? 1 : 0;    // LUI instructions
   assign isAUIPC    = (instR[6:0] == 7'b0010111) ? 1 : 0;  // AUIPC instructions
   assign isSYSTEM   = (instR[6:0] == 7'b1110011) ? 1 : 0; // System instructions

   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except shifts.
   /***************************************************************************/

   // First ALU source, always rs1
   logic [31:0] aluIn1, aluIn2, aluPlus;
   logic [32:0] aluMinus; 
   assign aluIn1 = rd1R; // ??

   // Second ALU source, depends on opcode
   //    ALUreg, Branch, ALUimm, Load, JALR
  assign aluIn2 = (isALUreg || isBranch) ? rd2R : Iimm; // ??

   // The adder is used by both arithmetic instructions and JALR.
  assign aluPlus = aluIn1 + aluIn2; // ??

   // Use a single 33 bits subtract to do subtraction and all comparisons
   assign aluMinus = aluIn1 + ~aluIn2 + 1'b1; // ??
   logic        LT, LTU, EQ;
   assign LT   = (($signed(aluIn1) - $signed(aluIn2)) < 0) ? 1 : 0;
   assign LTU  = (aluIn1 < aluIn2) ? 1 : 0;
   assign EQ   = (aluMinus == 0) ? 1 : 0;
   // assign LT, LTU, EQ = ; // ??

   logic [31:0] rightshift; // Note: SRA, SRL, SRAI, SRLI uses this
   
   always_comb begin
      rightshift = 32'b0;
      if (isALUimm) begin
         // SRAI & SRLI are ALU imm
            // SRAI = MSB extends & imm[11:5] = 0x20
            // SRLI = imm[11:5] = 0x00
         if (Iimm[11:5] == 7'b0100000) begin
            rightshift = $signed(rd1R) >> Iimm[4:0];
         end else if (Iimm[11:5] == 7'b0000000) begin
            rightshift = rd1R >> Iimm[4:0];
         end
      end else if (isALUreg) begin
         // SRA & SRL are ALU reg
            // SRA = MSB extends & funt7 = instR[31:25] = 0x20
            // SRL = funct7 = 0x00
         if (instR[31:25] == 7'b0100000) begin
            rightshift = $signed(rd1R) >> rd2R[4:0];
         end else if (instR[31:25] == 7'b0000000) begin
            rightshift = rd1R >> rd2R[4:0];
         end
      end
   end


   logic [31:0] leftshift; // Note: SLL, SLLI uses this
   // SLL is ALU reg
   // SLLI is ALU imm
   assign leftshift = (isALUimm) ? rd1R << Iimm[4:0] : rd1R << rd2R[4:0]; // ??

   // Notes: One hot and assign 0s to unused funct3Is[] entries
   // ALU output depends on func3
   // - funct7 opcode determines ADD/SUB and SRA/SRL. Note no SUBI instruction exists.   

   logic [31:0] aluOut, condinvb, sum, slt;

   assign condinvb = (isALUreg & instR[14:12] == 3'b000 & instR[30]) ? ~aluIn2 : aluIn2;
   assign sum      = aluIn1 + condinvb + (isALUreg & instR[14:12] == 3'b000 & instR[30]);
   assign slt      = (isALUimm) ? Iimm : aluIn2;

   assign aluOut =
     (funct3Is[0]  ? sum                              : 32'b0) |  // add, sum
     (funct3Is[1]  ? leftshift                        : 32'b0) |  // sll
     (funct3Is[2]  ? ($signed(aluIn1) < $signed(slt)) : 32'b0) |  // slt
     (funct3Is[3]  ? (aluIn1 < slt)                   : 32'b0) |  // sltu
     (funct3Is[4]  ? aluIn1 ^ aluIn2                  : 32'b0) |  // xor
     (funct3Is[5]  ? rightshift                       : 32'b0) |  // sra, srl, srai, srli
     (funct3Is[6]  ? aluIn1 | aluIn2                  : 32'b0) |  // or
     (funct3Is[7]  ? aluIn1 & aluIn2                  : 32'b0) ;  // and

   /***************************************************************************/
   // The branch condition (decision to branch or not) for conditional branch instructions. 
   // Depends on ALU & funct3 signals (BLT, BGE, BLTU, BGEU, BEQ, BNE)
   /***************************************************************************/

   logic branch_condition;
   assign branch_condition =
      (funct3Is[0] & EQ)   |  // Funct3 is 0 AND two operands are equal
      (funct3Is[1] & !EQ)  |  // Funct3 is 1 AND two operands are not equal
      (funct3Is[4] & LT)   |  // Funct3 is 4 AND rs1 is less than rs2
      (funct3Is[5] & !LT)  |  // Funct3 is 5 AND rs1 is not less than rs2
      (funct3Is[6] & LTU)  |  // Funct3 is 6 AND rs1 is less than rs2 (BOTH UNSIGNED)
      (funct3Is[7] & !LTU);   // Funct3 is 7 AND rs1 is not less than rs2 (BOTH UNSIGNED)

   /***************************************************************************/
   // Next Program counter, load/store address computation
   /***************************************************************************/
   logic [ADDR_WIDTH-1:0] PC, PCplus4, PCplusImm, PC_next;
   assign PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   assign PCplusImm = (isBranch) ? PC + Bimm[ADDR_WIDTH-1:0] : (isAUIPC) ? PC + Uimm[ADDR_WIDTH-1:0] : PC + Jimm[ADDR_WIDTH-1:0]; // ??

   logic jumpToPCplusImm; // Condition to jump to PCplusImm
   assign jumpToPCplusImm = (isBranch && branch_condition) || (isJAL); // || (isAUIPC); // ??

   // Next PC selection (handle PCplus4, PCplusImm, JALR)
   assign PC_next = (isJALR) ? aluOut[ADDR_WIDTH-1:0] : (jumpToPCplusImm) ? PCplusImm : PCplus4; // (aluIn1 + Iimm) && ~1'b1 : PCplus4; // ??


   /***************************************************************************/
   // LOAD/STORE (Already completed)
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary.
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   // Adder to compute load/store address
   logic [ADDR_WIDTH-1:0] loadstore_addr;
   assign loadstore_addr = rd1R[ADDR_WIDTH-1:0] + (isStore ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

   // Getting the funct3v alue from the instruction to see if it is byte or halfword addressed
   logic mem_byteAccess;     assign mem_byteAccess     = instR[13:12] == 2'b00; // funct3[1:0] == 2'b00;
   logic mem_halfwordAccess; assign mem_halfwordAccess = instR[13:12] == 2'b01; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on: bit 14
   // - funct3[2] (instr[14]): 0->sign expansion   1->sign expansion

   // Loading 2 bytes of the current address value depending on the second bit value
      // eg. Address 200: 11 22 33 44
      //     Address 204: 55 66 77 88
      // If address var is 200, then 200 (11001000) - bit 1 = 0 - ([22][11])
   logic [15:0] LOAD_halfword;
   assign LOAD_halfword = loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   // Loading 1 byte of the current address value depending on the second bit value
      // eg. Address 200: 11 22 33 44
      //     Address 204: 55 66 77 88
      // If address var is 200, then 200 (11001000) - bit 1 = 0 - ([22][11])
         // Bit 0 = 0 - ([11])
   logic [7:0]  LOAD_byte;
   assign LOAD_byte = loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   // 14th bit = 0 means sign extend - !0 = 1
   logic LOAD_sign;
   assign LOAD_sign = !instR[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);
 
   logic [31:0] LOAD_data;

   // always_comb begin
   //    if (mem_byteAccess) begin
   //       LOAD_data = {{24{LOAD_sign}}, LOAD_byte};
   //    end else if (mem_halfwordAccess) begin
   //       LOAD_data = {{16{LOAD_sign}}, LOAD_halfword};
   //    end else begin
   //       LOAD_data = mem_rdata;
   //    end
   // end

   assign LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :   // Byte addressing
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :   // Halfword addressing
                          mem_rdata ;                          // Word addressing

   // STORE

   // Put the data in all the places it might need to go
   // always_comb begin
   //    if (!mem_byteAccess && !mem_halfwordAccess) begin
   //       mem_wdata = rd2R;
   //    end else if (mem_byteAccess) begin
   //       mem_wdata[ 7: 0] = rd2R[7:0];
   //       mem_wdata[15: 8] = rd2R[7:0];
   //       mem_wdata[23:16] = rd2R[7:0];
   //       mem_wdata[31:24] = rd2R[7:0];
   //    end else if (mem_halfwordAccess) begin
   //       mem_wdata[ 7: 0] = rd2R[7:0];
   //       mem_wdata[15: 8] = rd2R[15:8];
   //       mem_wdata[23:16] = rd2R[7:0];
   //       mem_wdata[31:24] = rd2R[15:8];
   //    end
   // end

   assign mem_wdata[ 7: 0] = rd2R[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rd2R[7:0]  : rd2R[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rd2R[7:0]  : rd2R[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rd2R[7:0]  : loadstore_addr[1] ? rd2R[15:8] : rd2R[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on loadstore_addr[1:0])

   logic [3:0] STORE_wmask;

   // Upper 2 bytes -> Lower 2 bytes 

   // Addr: Byte3 Byte2 Byte1 Byte0
   // Mask: Bit3 Bit2 Bit1 Bit0

   // always_comb begin
   //    STORE_wmask = 4'b0000;
   //    if (!mem_byteAccess && !mem_halfwordAccess) begin
   //       STORE_wmask = 4'b1111;
   //    end else if (mem_byteAccess) begin
   //       if (loadstore_addr[1] == 0) begin
   //          if (loadstore_addr[0] == 0) begin
   //             STORE_wmask = 4'b0001;
   //          end else if (loadstore_addr[0] == 1) begin
   //             STORE_wmask = 4'b0010;
   //          end
   //       end else if (loadstore_addr[1] == 1) begin
   //          if (loadstore_addr[0] == 0) begin
   //             STORE_wmask = 4'b0100;
   //          end else if (loadstore_addr[0] == 1) begin
   //             STORE_wmask = 4'b1000;
   //          end
   //       end
   //    end else if (mem_halfwordAccess) begin
   //       STORE_wmask = (loadstore_addr[1] == 0) ? 4'b0011 : 4'b1100;
   //    end
   // end

   assign STORE_wmask =
	      mem_byteAccess      ?
	            (loadstore_addr[1] ?
		          (loadstore_addr[0] ? 4'b1000 : 4'b0100) :
		          (loadstore_addr[0] ? 4'b0010 : 4'b0001)
                    ) :
	      mem_halfwordAccess ?
	            (loadstore_addr[1] ? 4'b1100 : 4'b0011) :
              4'b1111;

   /***************************************************************************/
   // The value written back to the register file.
   // Instructions to consider:
   //   LUI, ALUreg, ALUimm, AUIPC, JAL, JALR, Load
   /***************************************************************************/

   assign writeBackData  =
      (isLUI               ? Uimm       : 32'b0) |  // LUI
      (isALU               ? aluOut     : 32'b0) |  // ALUreg, ALUimm
      (isAUIPC             ? PCplusImm  : 32'b0) |  // AUIPC
      (isJALR   | isJAL    ? PCplus4    : 32'b0) |  // JAL, JALR
      (isLoad              ? LOAD_data  : 32'b0) ;  // Load

   // (isSYSTEM            ? cycles     : 32'b0) |  // SYST EM
   /* verilator lint_on WIDTH */


   /*************************************************************************/
   // State Machine Declaration
   /*************************************************************************/

   typedef enum logic [3:0] {
      FETCH_INSTR = 4'b0001,
      WAIT_INSTR  = 4'b0010, 
      EXECUTE     = 4'b0100,
      WAIT_MEM    = 4'b1000
   } state_t;
   
   (* onehot *)
   state_t state, next_state;

   // The signals (internal and external) that are determined
   // combinatorially from state and other signals.
   // Next state and output logic

   logic needToWait;
   assign needToWait = isLoad | isStore ;

   always_comb begin
      // Default assignments
      mem_addr = PC;
      writeBack = 1'b0;
      mem_ren = 1'b0;
      mem_wmask = 4'b0000;
      rdR_en = 1'b0;
      instR_en = 1'b0;
      next_state = state;
      
      case(state)
         FETCH_INSTR: begin
            // ??
            mem_addr = PC;
            mem_ren = 1;
            mem_wmask = 0;
            next_state = WAIT_INSTR;
         end
         
         WAIT_INSTR: begin
            // ??
            if (mem_busy == 0) begin
               rdR_en = 1;
               instR_en = 1;
               next_state = EXECUTE;
            end
         end
         
         EXECUTE: begin
            // ??
            if (needToWait) begin
               mem_addr = loadstore_addr;
               if (isLoad) begin
                  mem_ren = 1;
               end else if (isStore) begin
                  mem_wmask = STORE_wmask;
               end
               next_state = WAIT_MEM;
            end else begin
               mem_addr = PC_next;  // CHANGED HERE
               writeBack = !isBranch && !isSYSTEM;
               mem_ren = 1; // CHANGED HERE
               next_state = WAIT_INSTR;   // CHANGED HERE
            end
         end
         
         WAIT_MEM: begin
           // ??
           if (mem_busy == 1) begin
            mem_addr = loadstore_addr;
            mem_ren = isLoad;
            mem_wmask = isStore ? STORE_wmask : 4'b0000;
           end
           if (mem_busy == 0) begin
               if (isLoad) begin
                  mem_addr = loadstore_addr;
                  writeBack = 1;
               end
               next_state = FETCH_INSTR;
            end
         end
      endcase
   end

   // State, PC, and instruction register updates
   always @(posedge clk) begin
      if(!reset) begin
         state      <= FETCH_INSTR; // HAD TO CHANGE FROM WAIT_MEM TO FETCH_INSTR
         PC         <= RESET_ADDR[ADDR_WIDTH-1:0];
         instR      <= 32'b0;
         for (int i = 0; i < 32; i++)
            registerFile[i] <= 32'b0;
      end else begin
         // Update PC
         if ((state == EXECUTE && !(needToWait)) || (state == WAIT_MEM && ~mem_busy)) begin
            PC <= PC_next;
         end
         // Instruction register update (controlled by instR_en)
         if (instR_en == 1) begin
            instR <= mem_rdata;
         end
         // Update state
         state <= next_state;
      end
   end

   /***************************************************************************/
   // Cycle counter
   /***************************************************************************/
   logic [31:0]         cycles;
   always @(posedge clk) begin
      if (!reset)
         cycles <= 0;
      else
      cycles <= cycles + 1;
   end

   /***************************************************************************/
   // Debug Monitor - Display cycle-by-cycle status
   /***************************************************************************/

   always @(posedge clk) begin
      $display("[CYCLE %0d] PC=0x%06h NextPC=0x%06h STATE=%b INSTR=0x%08h rdId=%d rd_val=0x%08h rs1=%d rs1_val=0x%08h rs2=%d rs2_val=0x%08h WriteBack=%b",
         cycles, PC, PC_next, state, instR, rdId, writeBackData, instR[19:15], rd1R, instR[24:20], rd2R, writeBack);
      if(writeBack) begin
         $display("\t[REG_WRITE] x%0d <= 0x%08h", rdId, writeBackData);
         $display("\tRegisterFile: x0=0x%08h x1=0x%08h x2=0x%08h x3=0x%08h x4=0x%08h x5=0x%08h x6=0x%08h x7=0x%08h",
            registerFile[0], registerFile[1], registerFile[2], registerFile[3],
            registerFile[4], registerFile[5], registerFile[6], registerFile[7]);
         $display("\t              x8=0x%08h x9=0x%08h x10=0x%08h x11=0x%08h x12=0x%08h x13=0x%08h x14=0x%08h x15=0x%08h",
            registerFile[8], registerFile[9], registerFile[10], registerFile[11],
            registerFile[12], registerFile[13], registerFile[14], registerFile[15]);
      end
      if (isBranch) begin
         $display("\t[BRANCH] branch_condition=%b jumpToPCplusImm=%b EQ=%b LT=%b LTU=%b aluIn1=0x%08h aluIn2=0x%08h PCplusImm=0x%06h", 
            branch_condition, jumpToPCplusImm, EQ, LT, LTU, aluIn1, aluIn2, PCplusImm);
      end
   end

endmodule
