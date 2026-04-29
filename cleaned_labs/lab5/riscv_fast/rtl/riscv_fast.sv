`timescale 1ns/1ps

module RV32I(
   input         clk,

   output logic [31:0] mem_addr,  // address bus
   output logic [31:0] mem_wdata, // data to be written
   output logic  [3:0] mem_wmask, // write mask for the 4 bytes of each word
   input  logic [31:0] mem_rdata, // input lines for both data and instr
   output logic        mem_ren, // active to initiate memory read (used by IO)
   input  logic         mem_busy, // asserted if memory is busy with read or write

   input  logic         reset      // set to 0 to reset the processor
);

   parameter RESET_ADDR       = 32'h00000000;
   parameter ADDR_WIDTH       = 24;



 /***************************************************************************/
 // Instruction decoding.
 /***************************************************************************/

 // Extracts rd,rs1,rs2,funct3,imm and opcode from instruction.

   // Sequential state (driven by always blocks)
   logic [31:0]         instR;        // Latched instruction. Note that bits 0 and 1 are
                                      // ignored (not used in RV32I base instr set).
   logic [ADDR_WIDTH-1:0] PC;         // The program counter
   logic [31:0]         cycles;

   // Forward declarations for register file control
   logic rdR_en, instR_en;

/***************************************************************************/
// The register file.
/***************************************************************************/
logic [31:0]         rd1R, rd2R, writeBackData;
logic writeBack;
logic [31:0]         registerFile [31:0];

   // Register identifiers
   logic [4:0] rs1Id, rs2Id, rdId;
   assign rdId = instR[11:7];
   assign rs1Id = mem_rdata[19:15];
   assign rs2Id = mem_rdata[24:20];

   always @(posedge clk) begin
      // Register file reads (controlled by rdR_en)
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


 // The ALU function, decoded in 1-hot form (doing so reduces LUT count)
 // It is used as follows: funct3Is[val] <=> funct3 == val
 (* onehot *)
 logic [7:0] funct3Is;
 assign funct3Is = 8'b00000001 << instR[14:12];

 // The five immediate formats, see RiscV reference (link above), Fig. 2.4 p. 12
 /* verilator lint_off UNUSED */ // MSBs of SBJimms are not used by addr adder.
   logic [31:0] Uimm, Iimm, Simm, Bimm, Jimm;
   assign Uimm = {    instR[31],   instR[30:12], {12{1'b0}}};
   assign Iimm = {{21{instR[31]}}, instR[30:20]};
   assign Simm = {{21{instR[31]}}, instR[30:25],instR[11:7]};
   assign Bimm = {{20{instR[31]}}, instR[7],instR[30:25],instR[11:8],1'b0};
   assign Jimm = {{12{instR[31]}}, instR[19:12],instR[20],instR[30:21],1'b0};
 /* verilator lint_on UNUSED */

   // Base RISC-V (RV32I) has only 10 different instructions
   logic isLoad, isALUimm, isAUIPC, isStore, isALUreg, isLUI, isBranch, isJALR, isJAL, isSYSTEM, isALU;
   assign isLoad    = (instR[6:2] == 5'b00000); // rd <- mem[rs1+Iimm]
   assign isALUimm  = (instR[6:2] == 5'b00100); // rd <- rs1 OP Iimm
   assign isAUIPC   = (instR[6:2] == 5'b00101); // rd <- PC + Uimm
   assign isStore   = (instR[6:2] == 5'b01000); // mem[rs1+Simm] <- rs2
   assign isALUreg  = (instR[6:2] == 5'b01100); // rd <- rs1 OP rs2
   assign isLUI     = (instR[6:2] == 5'b01101); // rd <- Uimm
   assign isBranch  = (instR[6:2] == 5'b11000); // if(rs1 OP rs2) PC<-PC+Bimm
   assign isJALR    = (instR[6:2] == 5'b11001); // rd <- PC+4; PC<-rs1+Iimm
   assign isJAL     = (instR[6:2] == 5'b11011); // rd <- PC+4; PC<-PC+Jimm
   assign isSYSTEM  = (instR[6:2] == 5'b11100); // rd <- cycles

   assign isALU = isALUimm | isALUreg;

   /***************************************************************************/
   // The ALU. Does operations and tests combinatorially, except shifts.
   /***************************************************************************/

   // First ALU source, always rs1
   logic [31:0] aluIn1, aluIn2, aluPlus;
   logic [32:0] aluMinus; 
   assign aluIn1 = rd1R;

   // Second ALU source, depends on opcode:
   //    ALUreg, Branch, ALUimm, Load, JALR
  assign aluIn2 = isALUreg | isBranch ? rd2R : Iimm;

   // The adder is used by both arithmetic instructions and JALR.
  assign aluPlus = aluIn1 + aluIn2;

   // Use a single 33 bits subtract to do subtraction and all comparisons
   assign aluMinus = {1'b1, ~aluIn2} + {1'b0,aluIn1} + 33'b1;
   logic        LT, LTU, EQ;
   assign LT  = (aluIn1[31] ^ aluIn2[31]) ? aluIn1[31] : aluMinus[32];
   assign LTU = aluMinus[32];
   assign EQ  = (aluMinus[31:0] == 0);

   logic [31:0] rightshift; // Note: SRA, SRL, SRAI, SRLI uses this
   assign rightshift = instR[30] ? ($signed(aluIn1) >>> aluIn2[4:0]) : (aluIn1 >> aluIn2[4:0]);

   logic [31:0] leftshift; // Note: SLL, SLLI uses this
   assign leftshift = aluIn1 << aluIn2[4:0];

   // Notes:
   // ALU output depends on func3
   // - funct7 opcode determines ADD/SUB and SRA/SRL. Note no SUBI instruction exists.   

   logic [31:0] aluOut;
   assign aluOut =
     (funct3Is[0]  ? instR[30] & instR[5] ? aluMinus[31:0] : aluPlus : 32'b0) |
     (funct3Is[1]  ? leftshift                                       : 32'b0) |
     (funct3Is[2]  ? {31'b0, LT}                                     : 32'b0) |
     (funct3Is[3]  ? {31'b0, LTU}                                    : 32'b0) |
     (funct3Is[4]  ? aluIn1 ^ aluIn2                                 : 32'b0) |
     (funct3Is[5]  ? rightshift                                      : 32'b0) |
     (funct3Is[6]  ? aluIn1 | aluIn2                                 : 32'b0) |
     (funct3Is[7]  ? aluIn1 & aluIn2                                 : 32'b0) ;

   /***************************************************************************/
   // The branch condition (decision) for conditional branch instructions. Depends on ALU & funct3 signals
   /***************************************************************************/

   logic branch_condition;
   assign branch_condition =
        funct3Is[0] &  EQ  | // BEQ
        funct3Is[1] & !EQ  | // BNE
        funct3Is[4] &  LT  | // BLT
        funct3Is[5] & !LT  | // BGE
        funct3Is[6] &  LTU | // BLTU
        funct3Is[7] & !LTU ; // BGEU

   /***************************************************************************/
   // Next Program counter, load/store address computation
   /***************************************************************************/

   logic [ADDR_WIDTH-1:0] PCplus4, PCplusImm, PC_next;
   assign PCplus4 = PC + 4;

   // An adder used to compute branch address, JAL address and AUIPC.
   // branch->PC+Bimm    AUIPC->PC+Uimm    JAL->PC+Jimm
   assign PCplusImm = PC + ( isJAL ? Jimm[ADDR_WIDTH-1:0] :
                             isAUIPC ? Uimm[ADDR_WIDTH-1:0] :
                                       Bimm[ADDR_WIDTH-1:0] );

   logic jumpToPCplusImm;
   assign jumpToPCplusImm = isJAL | (isBranch & branch_condition);

   // Next PC selection (needs to handle PCplus4, PCplusImm, JALR)
   assign PC_next =
      isJALR          ? {aluPlus[ADDR_WIDTH-1:1],1'b0} :
      jumpToPCplusImm ? PCplusImm                      :
                        PCplus4;


   /***************************************************************************/
   // LOAD/STORE
   /***************************************************************************/

   // All memory accesses are aligned on 32 bits boundary.
   // - funct3[1:0]:  00->byte 01->halfword 10->word
   // - mem_addr[1:0]: indicates which byte/halfword is accessed

   // A separate adder to compute the destination of load/store.
   // testing isStore is equivalent to testing instR[5] in this context.
   logic [ADDR_WIDTH-1:0] loadstore_addr;
   assign loadstore_addr = rd1R[ADDR_WIDTH-1:0] +
                   (isStore ? Simm[ADDR_WIDTH-1:0] : Iimm[ADDR_WIDTH-1:0]);

   logic mem_byteAccess;     assign mem_byteAccess     = instR[13:12] == 2'b00; // funct3[1:0] == 2'b00;
   logic mem_halfwordAccess; assign mem_halfwordAccess = instR[13:12] == 2'b01; // funct3[1:0] == 2'b01;

   // LOAD, in addition to funct3[1:0], LOAD depends on:
   // - funct3[2] (instr[14]): 0->do sign expansion   1->no sign expansion

   logic [15:0] LOAD_halfword;
   assign LOAD_halfword =
	       loadstore_addr[1] ? mem_rdata[31:16] : mem_rdata[15:0];

   logic [7:0]  LOAD_byte;
   assign LOAD_byte =
	       loadstore_addr[0] ? LOAD_halfword[15:8] : LOAD_halfword[7:0];

   logic LOAD_sign;
   assign LOAD_sign =
	!instR[14] & (mem_byteAccess ? LOAD_byte[7] : LOAD_halfword[15]);

   logic [31:0] LOAD_data;
   assign LOAD_data =
         mem_byteAccess ? {{24{LOAD_sign}},     LOAD_byte} :
     mem_halfwordAccess ? {{16{LOAD_sign}}, LOAD_halfword} :
                          mem_rdata ;

   // STORE

   assign mem_wdata[ 7: 0] = rd2R[7:0];
   assign mem_wdata[15: 8] = loadstore_addr[0] ? rd2R[7:0]  : rd2R[15: 8];
   assign mem_wdata[23:16] = loadstore_addr[1] ? rd2R[7:0]  : rd2R[23:16];
   assign mem_wdata[31:24] = loadstore_addr[0] ? rd2R[7:0]  :
		     loadstore_addr[1] ? rd2R[15:8] : rd2R[31:24];

   // The memory write mask:
   //    1111                     if writing a word
   //    0011 or 1100             if writing a halfword
   //                                (depending on loadstore_addr[1])
   //    0001, 0010, 0100 or 1000 if writing a byte
   //                                (depending on loadstore_addr[1:0])

   logic [3:0] STORE_wmask;
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

   logic needToWait;
   assign needToWait = isLoad | isStore ;

   // Next state and output logic
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
         // FETCH_INSTR: present PC address to BRAM and advance to WAIT_INSTR.
         // With 1-cycle BRAM latency the data will be valid on the next clock edge.
         FETCH_INSTR: begin
            mem_addr = PC;
            mem_ren = 1'b1;
            next_state = WAIT_INSTR;
         end
         
         // WAIT_INSTR: BRAM output (mem_rdata) is now valid.
         // Latch the instruction and read the register file.
         WAIT_INSTR: begin
            mem_addr = PC;
            mem_ren = 1'b1;

            if (!mem_busy) begin
               rdR_en = 1'b1;     // Enable register file reads
               instR_en = 1'b1;   // Enable instruction latch
               next_state = EXECUTE;
            end
         end
         
         EXECUTE: begin
            if (~isLoad & ~isStore) begin
               mem_addr = PC_next;
            end else begin
               mem_addr = loadstore_addr;
            end
            
            // Do NOT write back for loads here — memory data isn't ready yet.
            // Loads will write back in WAIT_MEM once mem_rdata is valid.
            writeBack = ~(isBranch | isStore | isLoad);
            mem_ren = ~isStore;
            mem_wmask = isStore ? STORE_wmask : 4'b0000;
            
            // For load/store go to WAIT_MEM (data arrives next cycle).
            // For non-memory instructions skip straight to WAIT_INSTR because
            // we already presented PC_next as the address in this cycle.
            next_state = needToWait ? WAIT_MEM : WAIT_INSTR;
         end
         
         // WAIT_MEM: BRAM output for load is now valid; write it back to regfile.
         // Also present PC to BRAM so the next instruction fetch starts.
         WAIT_MEM: begin
            mem_addr = PC;        // present PC so BRAM begins the next fetch
            mem_ren  = 1'b1;
            writeBack = isLoad;   // write loaded data back to register file

            if (!mem_busy) begin
               next_state = WAIT_INSTR; // data already presented; skip FETCH_INSTR
            end
         end
      endcase
   end

   // State, PC, and instruction register updates
   always @(posedge clk) begin
      if(!reset) begin
         state      <= WAIT_MEM; // Just waiting for !mem_wbusy
         PC         <= RESET_ADDR[ADDR_WIDTH-1:0];
         instR      <= 32'b0;
      end else begin
         // Update PC when in EXECUTE state
         if (state == EXECUTE) begin
            PC <= PC_next;
         end
            // Instruction latch (controlled by instR_en)
         if (instR_en) begin
            instR <= mem_rdata;
         end
         // Update state
         state <= next_state;
      end
   end

   /***************************************************************************/
   // Cycle counter
   /***************************************************************************/

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
      $display("[CYCLE %0d] PC=0x%06h NEXT=0x%06h STATE=%b INSTR=0x%08h WB=%b x%0d<=0x%08h",
         cycles, PC, PC_next, state, instR, writeBack, rdId, writeBackData);
   end

endmodule
