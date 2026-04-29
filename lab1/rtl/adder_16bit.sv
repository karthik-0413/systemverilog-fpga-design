// 16-bit Adder with Three Implementation Variations
//
// This design demonstrates three different ways to implement an adder:
//   1. BEHAVIORAL (default): Simple a + b using '+' operator
//   2. RIPPLE_CARRY_MANUAL: Manually instantiate 16 full adders one-by-one
//   3. RIPPLE_CARRY_GENERATE: Use generate statement with for loop
//
// To select implementation, define one of these before compilation:
//   -d BEHAVIORAL          (or don't define anything - this is default)
//   -d RIPPLE_CARRY_MANUAL
//   -d RIPPLE_CARRY_GENERATE
//
// All three implementations produce identical results!
// Students: Compare the code styles and understand the trade-offs.

`timescale 1ns / 1ps

module adder_16bit (
    input  logic [15:0] a,
    input  logic [15:0] b,
    output logic [15:0] sum,
    output logic        carry_out
);

`ifdef RIPPLE_CARRY_MANUAL
    //========================================================================
    // VARIATION 2: Manual Instantiation of 16 Full Adders
    //========================================================================
    // This shows explicit instantiation of each full adder.
    // Advantage: Clear and explicit - you see every connection
    // Disadvantage: Tedious, error-prone for large designs, hard to modify

    logic [16:0] c;  // Carry chain: c[0] is carry_in, c[16] is carry_out

    assign c[0] = 1'b0;  // No carry input

    // Manually instantiate all 16 full adders
    full_adder fa0  (.a(a[0]),  .b(b[0]),  .cin(c[0]),  .sum(sum[0]),  .cout(c[1]));
    full_adder fa1  (.a(a[1]),  .b(b[1]),  .cin(c[1]),  .sum(sum[1]),  .cout(c[2]));
    full_adder fa2  (.a(a[2]),  .b(b[2]),  .cin(c[2]),  .sum(sum[2]),  .cout(c[3]));
    full_adder fa3  (.a(a[3]),  .b(b[3]),  .cin(c[3]),  .sum(sum[3]),  .cout(c[4]));
    full_adder fa4  (.a(a[4]),  .b(b[4]),  .cin(c[4]),  .sum(sum[4]),  .cout(c[5]));
    full_adder fa5  (.a(a[5]),  .b(b[5]),  .cin(c[5]),  .sum(sum[5]),  .cout(c[6]));
    full_adder fa6  (.a(a[6]),  .b(b[6]),  .cin(c[6]),  .sum(sum[6]),  .cout(c[7]));
    full_adder fa7  (.a(a[7]),  .b(b[7]),  .cin(c[7]),  .sum(sum[7]),  .cout(c[8]));
    full_adder fa8  (.a(a[8]),  .b(b[8]),  .cin(c[8]),  .sum(sum[8]),  .cout(c[9]));
    full_adder fa9  (.a(a[9]),  .b(b[9]),  .cin(c[9]),  .sum(sum[9]),  .cout(c[10]));
    full_adder fa10 (.a(a[10]), .b(b[10]), .cin(c[10]), .sum(sum[10]), .cout(c[11]));
    full_adder fa11 (.a(a[11]), .b(b[11]), .cin(c[11]), .sum(sum[11]), .cout(c[12]));
    full_adder fa12 (.a(a[12]), .b(b[12]), .cin(c[12]), .sum(sum[12]), .cout(c[13]));
    full_adder fa13 (.a(a[13]), .b(b[13]), .cin(c[13]), .sum(sum[13]), .cout(c[14]));
    full_adder fa14 (.a(a[14]), .b(b[14]), .cin(c[14]), .sum(sum[14]), .cout(c[15]));
    full_adder fa15 (.a(a[15]), .b(b[15]), .cin(c[15]), .sum(sum[15]), .cout(c[16]));

    assign carry_out = c[16];

`elsif RIPPLE_CARRY_GENERATE
    //========================================================================
    // VARIATION 3: Generate Statement with For Loop
    //========================================================================
    // This uses SystemVerilog generate to create full adders programmatically.
    // Advantage: Scalable, easy to modify (change 16 to 32 in one place!)
    // Disadvantage: Slightly less explicit, requires understanding generate

    logic [16:0] c;  // Carry chain: c[0] is carry_in, c[16] is carry_out

    assign c[0] = 1'b0;  // No carry input

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : gen_ripple_adder
            full_adder fa (
                .a(a[i]),
                .b(b[i]),
                .cin(c[i]),
                .sum(sum[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    assign carry_out = c[16];

`else  // BEHAVIORAL (default)
    //========================================================================
    // VARIATION 1: Behavioral Description (DEFAULT)
    //========================================================================
    // This uses the '+' operator and lets synthesis tool decide implementation.
    // Advantage: Simple, readable, tool will optimize for target technology
    // Disadvantage: Less control over exact hardware structure

    logic [16:0] result;

    assign result = {1'b0, a} + {1'b0, b};
    assign sum = result[15:0];
    assign carry_out = result[16];

`endif

endmodule
