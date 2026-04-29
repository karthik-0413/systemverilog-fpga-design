// bram_4kb.sv
// 4KB BRAM for APB program simulation with verilog.hex support

`timescale 1ns/1ps

module bram_4kb(
    input  logic        clk,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic [3:0]  wmask,
    input  logic        we,
    output logic [31:0] rdata
);

    logic [31:0] mem [0:1023]; // 1024 words = 4KB

    initial begin
        $readmemh("program.verilog.hex", mem);
    end

    always_ff @(posedge clk) begin
        rdata <= mem[addr[14:2]];
    end

    always_ff @(posedge clk) begin
        if (we) begin
            if (wmask[0]) mem[addr[31:2]][7:0]   <= wdata[7:0];
            if (wmask[1]) mem[addr[31:2]][15:8]  <= wdata[15:8];
            if (wmask[2]) mem[addr[31:2]][23:16] <= wdata[23:16];
            if (wmask[3]) mem[addr[31:2]][31:24] <= wdata[31:24];
        end
    end

endmodule
