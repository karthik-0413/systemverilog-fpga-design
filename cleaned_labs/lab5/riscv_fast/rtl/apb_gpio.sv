// apb_gpio.sv
// APB GPIO peripheral with two independent 8-bit I/O registers.
//
// TEACHING NOTES FOR STUDENTS:
// =============================
// This GPIO peripheral demonstrates a simple parallel I/O interface:
// - Input register (gpio_in): Reads external input pins into a 32-bit register.
// - Output register (gpio_out): Writes to external output pins (8 LSBs used).
// - Both registers are independently addressable at different offsets.
// - The peripheral uses 8-bit pin vectors; upper 24 bits are zero-padded.
//
// KEY CONCEPTS:
// - APB addresses are word-aligned and decoded by byte offset.
// - Address selection uses paddr[3:2] to pick between 4 possible registers.
// - addr_hit validates that the requested address belongs to this peripheral.
// - write_hit combines APB handshake signals to detect a valid write operation.
//
// REGISTER MAP (byte offsets from peripheral base):
// ===================================================
// Address  | Name    | Type      | Bits | Description
// ----------+---------+-----------+------+----------------------------------------
// 0x00     | gpio_in | read-only | 31:0 | External input pins. Software reads
//          |         |           |      | to sample the gpio_in[7:0] pins.
//          |         |           |      | Upper 24 bits are always 0.
// 0x04     | gpio_out| read/write| 31:0 | External output pins. Software writes
//          |         |           |      | gpio_out[7:0] to drive the pins.
//          |         |           |      | Upper 24 bits are ignored.

`timescale 1ns/1ps

module apb_gpio(
    input  logic        clk,
    input  logic        reset,

    input  logic [31:0] paddr,
    input  logic [31:0] pwdata,
    input  logic        psel,
    input  logic        penable,
    input  logic        pwrite,
    output logic [31:0] prdata,
    output logic        pready,
    output logic        pslverr,

    input  logic [7:0]  gpio_in,
    output logic [7:0]  gpio_out
);

    logic [31:0] gpio_in_reg;
    logic [31:0] gpio_out_reg;
    logic [1:0]  reg_sel;
    logic        addr_hit;
    logic        write_hit;

    //------------------------------------------------------------------------
    // APB ADDRESS DECODING
    //------------------------------------------------------------------------
    // Extract the word offset from paddr[3:2] to select registers:
    //   2'b00 (0x00): gpio_in register (READ-ONLY)
    //   2'b01 (0x04): gpio_out register 
    //   others:       not used in this peripheral
    // My Notes:
    // There are a total of 2 registers in this peripheral, so it needs 2 bits to select the register.
    // You ignore the first 2 bits (0 & 1) because the APB addresses are word-aligned, meaning they increment in steps of 4 bytes (32 bits).
    assign reg_sel = paddr[3:2];

    // Check if the requested address belongs to this GPIO peripheral.
    // Only addresses 0x00 and 0x04 are valid; others produce no effect.
    assign addr_hit = (reg_sel == 2'b00) || (reg_sel == 2'b01);

    // A write is accepted only when all these conditions hold:
    //   - psel = 1 (this slave is selected)
    //   - penable = 1 (APB access phase—not setup phase)
    //   - pwrite = 1 (this is a write, not a read)
    //   - addr_hit = 1 (the address is gpio_out)
    // Write to gpio_in are ignored since it's read-only; only gpio_out can be written.
    assign write_hit = psel && penable && pwrite && (reg_sel == 2'b01);

    //------------------------------------------------------------------------
    // OUTPUT ASSIGNMENTS
    //------------------------------------------------------------------------
    // Drive the 8-bit output pins from the LSBs of gpio_out_reg.
    // Upper 24 bits are not used; only bits [7:0] affect the pins.
    assign gpio_out = gpio_out_reg[7:0];

    // APB interface signals (required for protocol compliance).
    assign pready = 1'b1;  // No wait states; always ready immediately.
    assign pslverr = 1'b0; // No error responses in this lab.

    //------------------------------------------------------------------------
    // SEQUENTIAL LOGIC: Register Updates and I/O Sampling
    //------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!reset) begin
            // Reset clears both registers to zero.
            gpio_in_reg  <= 32'h0000_0000;
            gpio_out_reg <= 32'h0000_0000;
        end else begin
            // STEP 1: Sample external inputs every clock.
            // The gpio_in register continuously reads the external gpio_in[7:0]
            gpio_in_reg <= {24'h000000, gpio_in};

            // STEP 2: Handle APB writes to gpio_out.
            // When software writes to 0x04 (gpio_out)
            if (write_hit) begin
                gpio_out_reg <= {24'h000000, pwdata[7:0]};
            end
        end
    end

    //------------------------------------------------------------------------
    // COMBINATORIAL READ LOGIC: APB Readback Multiplexer
    //------------------------------------------------------------------------
    always_comb begin
        // APB readback is selected by the same address bits used for writes.
        // This case statement must match the address decoding logic so that
        // the read and write paths use consistent addressing.
        unique case (reg_sel)
            2'b00: prdata = gpio_in_reg;   // @0x00: read sampled input pins
            2'b01: prdata = gpio_out_reg;  // @0x04: read output register (for debug)
            default: prdata = 32'h0000_0000;  // Invalid addresses return zeros
        endcase
    end

endmodule
