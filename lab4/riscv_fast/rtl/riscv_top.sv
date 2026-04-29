// riscv_top.sv
// Top module for RISC-V fast processor with BRAM

`timescale 1ns/1ps

module riscv_top(
    input  logic        clk,
    input  logic        reset,

    // Debug outputs (same interface as single-cycle version)
    output logic [31:0] WriteData,
    output logic [31:0] DataAdr,
    output logic        MemWrite
);

    // Signals to connect to FemtoRV32 core
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [3:0]  mem_wmask;
    logic [31:0] mem_rdata;
    logic        mem_ren;
    logic        mem_busy;

    // Instantiate the RISC-V core
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

    // Instantiate BRAM module with combinatorial read
    bram bram_inst(
        .clk(clk),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .we(mem_wmask != 4'b0000),
        .rdata(mem_rdata)
    );

    // For this simple implementation, the BRAM is always ready
    assign mem_busy = 1'b0;

    // Debug outputs (same interface as single-cycle for compatibility)
    assign WriteData = mem_wdata;
    assign DataAdr = mem_addr;
    assign MemWrite = (mem_wmask != 4'b0000);

endmodule
