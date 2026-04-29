// riscv_top.sv
// Top module for the fast RISC-V core, BRAM, and the APB peripheral block.
//
// Teaching note:
// - Low addresses go to BRAM.
// - High addresses in the APB window go through the APB bridge.
// - The APB bridge then fans out to GPIO0 and the timer.

`timescale 1ns/1ps

module riscv_top(
    input  logic        clk,
    input  logic        reset,

    input  logic [7:0]  gpio0_in,
    output logic [7:0]  gpio0_out,

    // Debug outputs (same interface as single-cycle version)
    output logic [31:0] WriteData,
    output logic [31:0] DataAdr,
    output logic        MemWrite
);

    localparam logic [31:0] BRAM_BASE       = 32'h0000_0000;
    localparam logic [31:0] APB_BASE        = 32'h0004_0000;
    localparam logic [31:0] APB_LIMIT       = 32'h0004_07FF;

    // Core-facing memory interface.
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic        mem_ren;
    logic        mem_busy;

    // TODO: Address decode between BRAM and APB.
    logic        is_bram_addr;
    assign is_bram_addr = (mem_addr[31:12] == BRAM_BASE[31:12]);
    logic        is_apb_addr;
    assign is_apb_addr = (mem_addr >= APB_BASE) && (mem_addr <= APB_LIMIT);

    // BRAM path signals.
    logic [31:0] bram_rdata;
    logic        bram_we;
    assign bram_we = is_bram_addr && (mem_wmask != 4'b0000);

    // APB response path.
    logic        apb_busy;
    logic        apb_resp_valid;
    logic [31:0] apb_resp_rdata;
    logic        apb_req_valid;


    // Instantiate the FemtoRV32 core.
    RV32I riscv_core(
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_ren(mem_ren),
        .mem_busy(mem_busy),
        .reset(reset)
    );

    // Keep BRAM on the direct fast path for low addresses.
    bram_4kb bram_inst(
        .clk(clk),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .we(bram_we),
        .rdata(bram_rdata)
    );

    // APB subsystem.
    apb_top apb_subsystem(
        .clk(clk),
        .reset(reset),
        .req_valid(apb_req_valid),
        .req_addr(mem_addr),
        .req_wdata(mem_wdata),
        .req_wmask(mem_wmask),
        .busy(apb_busy),
        .resp_valid(apb_resp_valid),
        .resp_rdata(apb_resp_rdata),
        .gpio0_in(gpio0_in),
        .gpio0_out(gpio0_out)
    );
    
    // TODO: APB req valid . Under what condition is the APB request valid? 
    assign apb_req_valid = is_apb_addr && (mem_ren || (mem_wmask != 4'b0000));

    // TODO: Memory read data for CPU ( from BRAM vs (MMIO) APB vs default case) & busy signal fpr CPU
    assign mem_rdata = (apb_busy || apb_resp_valid) ? apb_resp_rdata :
                       is_bram_addr                 ? bram_rdata :
                                                       32'h0000_0000;
    assign mem_busy = apb_busy;

    // Debug outputs.
    assign WriteData = mem_wdata;
    assign DataAdr   = mem_addr;
    assign MemWrite  = (mem_wmask != 4'b0000);

endmodule
