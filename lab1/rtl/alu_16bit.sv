// 16-bit ALU with for different operations
//
// This design includes:
//   - 000 = Addition
//   - 001 = Subtraction
//   - 010 = Multiplication
//   - 011 = Bitwise AND
//   - 100 = Bitwise OR
//   - 101 = Bitwise XOR
//   - 110 = Shifting (left and right)
//   - 111 = Invalid

`timescale 1ns/1ps

module alu_16bit (
    input logic signed [15:0] a,
    input logic signed [15:0] b,
    input logic signed [4:0] shift_amount,
    input logic [2:0] control,
    output logic signed [31:0] result
);

    always @(*) begin
        if (control == 3'b000) begin
            result = {{16{a[15]}}, a} + {{16{b[15]}}, b};
        end
        else if (control == 3'b001) begin
            result = {{16{a[15]}}, a} - {{16{b[15]}}, b};
        end
        else if (control == 3'b010) begin
            result = a * b;
        end
        else if (control == 3'b011) begin
            result = {16'b0, a & b};
        end
        else if (control == 3'b100) begin
            result = {16'b0, a | b};
        end
        else if (control == 3'b101) begin
            result = {16'b0, a ^ b};
        end
        // (-16 to +15)
        // Result sign-extended to 32 bits
        else if (control == 3'b110) begin
            if (shift_amount >= 0) begin
                result = $signed({{16{a[15]}}, a}) <<< shift_amount;
            end
            else begin
                result = $signed({{16{a[15]}}, a}) >>> -(shift_amount);
            end
        end
        else begin
            // INVALID
            result = 32'b0;
        end
    end

endmodule