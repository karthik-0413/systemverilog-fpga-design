// Verilog wrapper for SystemVerilog adder_16bit module
// This allows the SystemVerilog module to be used in Vivado block design

module adder_16bit_wrapper (
    input  [15:0] a,
    input  [15:0] b,
    output [16:0] sum
);

    adder_16bit adder_inst (
        .a(a),
        .b(b),
        .sum(sum[15:0]),
        .carry_out(sum[16])
    );

endmodule