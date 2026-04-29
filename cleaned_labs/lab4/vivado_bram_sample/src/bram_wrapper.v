// bram_wrapper.v
// Wrapper for FSM to connect to block design

`timescale 1ns/1ps

module bram_wrapper(
    input  wire         clk,
    input  wire         reset,    // Active-high reset (from GPIO ch1). Deassert to start.

    // BRAM Port B - standard Xilinx BRAM interface (auto-connects in block design)
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_SIZE 4096, MEM_WIDTH 32, MEM_ECC NONE, READ_WRITE_MODE READ_WRITE, READ_LATENCY 1" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    output wire        bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    output wire        bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    output wire [3:0]  bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    output wire [31:0] bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    output wire [31:0] bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    input  wire [31:0] bram_dout,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST" *)
    output wire        bram_rst,

    // Status output
    output wire        done
);

    // Internal signals
    wire [31:0] addr;
    wire [31:0] wdata;
    wire [3:0]  wmask;
    wire        we;
    wire [31:0] rdata;

    // Instantiate FSM - USE MY RISC V CPU HERE INSTEAD OF THE FSM
    // bram_test_fsm fsm_inst(
    //     .clk(clk),
    //     .reset(reset),
    //     .addr(addr),
    //     .wdata(wdata),
    //     .wmask(wmask),
    //     .we(we),
    //     .rdata(rdata),
    //     .done(done)
    // );

    RV32I cpu_inst(
        .clk(clk),
        .reset(reset),
        .mem_addr(addr),
        .mem_wdata(wdata),
        .mem_wmask(wmask),
        .mem_rdata(rdata),
        .mem_ren(we),
        .mem_busy(mem_busy)
    );

    // Drive BRAM Port B interface
    assign bram_clk = clk;
    assign bram_rst = 1'b0;
    assign bram_en = 1'b1;

    assign bram_addr = addr;
    assign bram_din  = wdata;
    assign bram_we   = wmask;
    assign rdata     = bram_dout;
    assign mem_busy = 1'b0;
    assign done = 1'b0;

endmodule
