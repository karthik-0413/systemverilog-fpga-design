// riscv_wrapper.v
// Wrapper for RV32I core to connect to block design
// Includes: BUFGCE clock gate, step FSM, 8:1 32-bit debug mux
//
// Block design connections:
//   - BRAM Port B  → shared True Dual-Port BRAM (Port A: AXI BRAM Controller / PS)
//   - debug_ctrl   → AXI GPIO ch1 (5-bit: [4]=free_run, [3]=step, [2:0]=mux_sel)
//   - debug_out    → AXI GPIO ch2 (32-bit read-back)
//   - reset        → AXI GPIO ch1 (active-high)
//
// IMPORTANT: RV32I uses active-LOW reset (reset=0 → resets the core).
//            The GPIO drives active-HIGH, so the wrapper inverts it.

`timescale 1ns/1ps

module riscv_wrapper (
    input  wire         clk,
    input  wire         reset,          // Active-high from GPIO. Deassert (0) to run.

    // BRAM Port B — standard Xilinx BRAM interface (auto-connects in block design)
    (* X_INTERFACE_PARAMETER = "MASTER_TYPE BRAM_CTRL, MEM_SIZE 4096, MEM_WIDTH 32, MEM_ECC NONE, READ_WRITE_MODE READ_WRITE, READ_LATENCY 1" *)
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB CLK" *)
    output wire         bram_clk,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB EN" *)
    output wire         bram_en,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB WE" *)
    output wire [3:0]   bram_we,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB ADDR" *)
    output wire [31:0]  bram_addr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DIN" *)
    output wire [31:0]  bram_din,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB DOUT" *)
    input  wire [31:0]  bram_dout,
    (* X_INTERFACE_INFO = "xilinx.com:interface:bram:1.0 BRAM_PORTB RST" *)
    output wire         bram_rst,

    // Debug interface: [4]=free_run, [3]=step, [2:0]=mux select
    input  wire [4:0]   debug_ctrl,
    output wire [31:0]  debug_out
);

    // -------------------------------------------------------
    // RV32I memory-interface signals
    // -------------------------------------------------------
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wmask;
    wire [31:0] mem_rdata;
    wire        mem_ren;
    wire        mem_write;

    assign mem_write = (mem_wmask != 4'b0000);

    // -------------------------------------------------------
    // Step FSM — runs on ungated clk, controls BUFGCE CE
    // States: WAIT_STEP(0) → PULSE(1) → WAIT_LOW(2)
    // -------------------------------------------------------
    localparam STEP_WAIT     = 2'd0;
    localparam STEP_PULSE    = 2'd1;
    localparam STEP_WAIT_LOW = 2'd2;

    reg  [1:0] step_state;
    reg        clk_en;
    wire       step     = debug_ctrl[3];
    wire       free_run = debug_ctrl[4];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            step_state <= STEP_WAIT;
            clk_en     <= 1'b0;
        end else begin
            case (step_state)
                STEP_WAIT: begin
                    clk_en <= 1'b0;
                    if (step)
                        step_state <= STEP_PULSE;
                end
                STEP_PULSE: begin
                    clk_en     <= 1'b1;
                    step_state <= STEP_WAIT_LOW;
                end
                STEP_WAIT_LOW: begin
                    clk_en <= 1'b0;
                    if (!step)
                        step_state <= STEP_WAIT;
                end
                default: begin
                    step_state <= STEP_WAIT;
                    clk_en     <= 1'b0;
                end
            endcase
        end
    end

    // -------------------------------------------------------
    // BUFGCE: glitch-free clock gate for 7-series
    //   CE high when: step FSM pulses  OR  free_run asserted
    // -------------------------------------------------------
    wire gated_clk;

    BUFGCE bufgce_i (
        .I  (clk),
        .CE (clk_en | free_run),
        .O  (gated_clk)
    );

    // -------------------------------------------------------
    // RV32I core (clocked by gated_clk)
    //
    //   Core reset is ACTIVE-LOW  (reset=0 → resets)
    //   GPIO reset is ACTIVE-HIGH (reset=1 → resets)
    //   → invert: pass ~reset to core
    // -------------------------------------------------------
    RV32I riscv_core (
        .clk       (gated_clk),
        .reset     (~reset),        // invert: active-high → active-low
        .mem_addr  (mem_addr),
        .mem_wdata (mem_wdata),
        .mem_wmask (mem_wmask),
        .mem_rdata (mem_rdata),
        .mem_ren   (mem_ren),
        .mem_busy  (1'b0)           // BRAM never stalls
    );

    // -------------------------------------------------------
    // Drive BRAM Port B interface
    //   CPU memory bus directly maps to the dual-port BRAM.
    //   PS uploads instructions through Port A (AXI BRAM Ctrl).
    //   CPU fetches/stores through Port B (here).
    // -------------------------------------------------------
    assign bram_clk  = gated_clk;
    assign bram_en   = 1'b1;
    assign bram_we   = mem_wmask;
    assign bram_addr = mem_addr;
    assign bram_din  = mem_wdata;
    assign mem_rdata = bram_dout;
    assign bram_rst  = 1'b0;

    // -------------------------------------------------------
    // 8:1 32-bit debug mux
    //   sel 0 : mem_addr   — address bus (PC during fetch,
    //                         load/store addr during mem ops)
    //   sel 1 : mem_wdata  — data being written to memory
    //   sel 2 : mem_rdata  — data read from BRAM (fetched
    //                         instruction or load data)
    //   sel 3 : mem_wmask  — byte-write mask  (4-bit → 32-bit)
    //   sel 4 : mem_write  — write-enable flag (1-bit → 32-bit)
    //   sel 5 : mem_ren    — read-enable flag  (1-bit → 32-bit)
    //   sel 6 : step_state — step FSM state    (2-bit → 32-bit)
    //   sel 7 : (reserved)   32'b0
    // -------------------------------------------------------
    wire [2:0] sel = debug_ctrl[2:0];
    reg  [31:0] mux_out;

    always @(*) begin
        case (sel)
            3'd0: mux_out = mem_addr;
            3'd1: mux_out = mem_wdata;
            3'd2: mux_out = mem_rdata;
            3'd3: mux_out = {28'b0, mem_wmask};
            3'd4: mux_out = {31'b0, mem_write};
            3'd5: mux_out = {31'b0, mem_ren};
            3'd6: mux_out = {30'b0, step_state};
            3'd7: mux_out = 32'b0;
            default: mux_out = 32'b0;
        endcase
    end

    assign debug_out = mux_out;

endmodule