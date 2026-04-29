`timescale 1ns/1ps

module alu_16bit_wrapper (
    input  [15:0] a,
    input  [15:0] b,
    input  [4:0]  shift_amount,
    input  [2:0]  control,
    output [31:0] result
);

    // Instantiate the SystemVerilog ALU
    alu_16bit alu_inst (
        .a(a),
        .b(b),
        .shift_amount(shift_amount),
        .control(control),
        .result(result)
    );

endmodule
