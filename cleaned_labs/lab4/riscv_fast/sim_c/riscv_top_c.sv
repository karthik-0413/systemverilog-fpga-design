// riscv_top_c.sv
// Top module for RISC-V fast processor with 4KB BRAM for C simulation

`timescale 1ns/1ps

module riscv_top_c(
    input  logic        clk,
    input  logic        reset,

    // Debug outputs
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

    // Instantiate the FemtoRV32 core
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

    // Instantiate 4KB BRAM module
    bram_4kb bram_inst(
        .clk(clk),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .wmask(mem_wmask),
        .we(mem_wmask != 4'b0000),
        .rdata(mem_rdata)
    );

    // For this simple implementation, assume BRAM is always ready
    assign mem_busy = 1'b0;

    // Debug outputs
    assign WriteData = mem_wdata;
    assign DataAdr = mem_addr;
    assign MemWrite = (mem_wmask != 4'b0000);

endmodule
