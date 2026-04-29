// Testbench 1: Random Testing with Simple Classes
//
// This testbench demonstrates:
//   - Simple SystemVerilog classes for stimulus generation
//   - Constrained random testing
//   - Directed corner case testing
//   - Basic scoreboard checking

`timescale 1ns / 1ps

module tb_alu_random;

    // Testbench signals
    logic signed [15:0] a;
    logic signed [15:0] b;
    logic signed [4:0] shift_amount;
    logic [2:0] control;
    logic signed [31:0] result;

    // Instantiate DUT
    alu_16bit dut (
        .a(a),
        .b(b),
        .shift_amount(shift_amount),
        .control(control),
        .result(result)
    );

    // Simple Transaction Class
    class Transaction;
        rand bit signed [15:0] a;
        rand bit signed [15:0] b;
        rand bit signed [4:0] shift_amount;
        rand bit [2:0] control;
        bit signed [31:0] result;

        // Constraints for interesting test cases
        constraint corner_cases {
            // Bias towards corner cases (30% of the time)
            // Weights: 10+10+5+5 = 30 for corners, 70 for random = 100 total
            a dist { 16'h0000 := 10,      // Zero
                     16'hFFFF := 10,      // Max value
                     16'h8000 := 5,       // MSB set
                     16'h0001 := 5,       // Minimum non-zero
                     [1:16'hFFFE] := 70}; // Random values

            b dist { 16'h0000 := 10,
                     16'hFFFF := 10,
                     16'h8000 := 5,
                     16'h0001 := 5,
                     [1:16'hFFFE] := 70};
        }

        function void display(string prefix = "");
            $display("%sTransaction: a=%h, b=%h, shift=%0d, control=%b, result=%h",
                    prefix, a, b, shift_amount, control, result);
        endfunction
    endclass

    // Simple Scoreboard Class
    class Scoreboard;
        int pass_count = 0;
        int fail_count = 0;

        function void check(Transaction tr);
            logic [31:0] expected;
            // expected = {1'b0, tr.a} + {1'b0, tr.b};
            if (tr.control == 3'b000) begin
                expected = {{16{tr.a[15]}}, tr.a} + {{16{tr.b[15]}}, tr.b};
            end
            else if (tr.control == 3'b001) begin
                expected = {{16{tr.a[15]}}, tr.a} - {{16{tr.b[15]}}, tr.b};
            end
            else if (tr.control == 3'b010) begin
                expected = tr.a * tr.b;
            end
            else if (tr.control == 3'b011) begin
                expected = {16'b0, tr.a & tr.b};
            end
            else if (tr.control == 3'b100) begin
                expected = {16'b0, tr.a | tr.b};
            end
            else if (tr.control == 3'b101) begin
                expected = {16'b0, tr.a ^ tr.b};
            end
            else if (tr.control == 3'b110) begin
                if (tr.shift_amount >= 0) begin
                    expected = $signed({{16{tr.a[15]}}, tr.a}) <<< tr.shift_amount;
                end
                else begin
                    expected = $signed({{16{tr.a[15]}}, tr.a}) >>> -(tr.shift_amount);
                end
            end
            else begin
                // INVALID
                expected = 32'b0;
            end

            if (tr.result === expected[31:0]) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("ERROR: Mismatch detected!");
                $display("  Inputs:   a=%h, b=%h, shift_amount,=%h, control=%h", tr.a, tr.b, tr.shift_amount, tr.control);
                $display("  Expected: result=%h", expected[31:0]);
                $display("  Got:      result=%h", tr.result);
            end
        endfunction

        function void report();
            $display("\n========================================");
            $display("  Scoreboard Summary");
            $display("========================================");
            $display("Passed: %0d", pass_count);
            $display("Failed: %0d", fail_count);
            $display("Total:  %0d", pass_count + fail_count);
            if (fail_count == 0)
                $display("\n*** ALL TESTS PASSED! ***");
            else
                $display("\n*** SOME TESTS FAILED! ***");
            $display("========================================\n");
        endfunction
    endclass

    // Test execution
    initial begin
        Transaction tr;
        Scoreboard sb;
        static int num_random_tests = 10000;

        $display("========================================");
        $display("  16-bit Adder Constrained Random Test");
        $display("========================================\n");

        tr = new();
        sb = new();

        // Part 1: Directed Corner Cases
        $display("Part 1: Directed Corner Case Tests\n");

        // Test 1: ADD
        a = 16'h0000; b = 16'h0000; shift_amount = 2'b01; control = 3'b000; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 1: ");
        sb.check(tr);

        // Test 2: SUB
        a = 16'hFFFF; b = 16'hFFFF; shift_amount = 2'b01; control = 3'b001; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 2: ");
        sb.check(tr);

        // Test 3: MUL
        a = 16'h0000; b = 16'hFFFF; shift_amount = 2'b01; control = 3'b010; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 3: ");
        sb.check(tr);

        // Test 4: AND
        a = 16'hFFFF; b = 16'h0000; shift_amount = 2'b01; control = 3'b011; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 4: ");
        sb.check(tr);

        // Test 5: OR
        a = 16'h8000; b = 16'h8000; shift_amount = 2'b01; control = 3'b100; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 5: ");
        sb.check(tr);

        // Test 6: XOR
        a = 16'hFFFF; b = 16'h0000; shift_amount = 2'b01; control = 3'b101; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 6: ");
        sb.check(tr);

        // Test 7: Shift Left
        a = 16'h0010; b = 16'h0001; shift_amount = 5; control = 3'b110; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 7: ");
        sb.check(tr);

        // Test 8: Shift Right
        a = 16'h0010; b = 16'h0001; shift_amount = -5; control = 3'b110; #10;
        tr.a = a; tr.b = b; tr.shift_amount = shift_amount; tr.control = control; tr.result = result;
        tr.display("  Corner case 8: ");
        sb.check(tr);

        // Part 2: Constrained Random Tests
        $display("\nPart 2: Constrained Random Tests (%0d iterations)\n", num_random_tests);

        for (int i = 0; i < num_random_tests; i++) begin
            // Randomize inputs
            if (!tr.randomize()) begin
                $display("ERROR: Randomization failed!");
                $finish;
            end

            // Apply to DUT
            a = tr.a;
            b = tr.b;
            shift_amount = tr.shift_amount;
            control = tr.control;
            #10;

            // Capture outputs
            tr.result = result;

            // Check result
            sb.check(tr);

            // Display progress
            if ((i + 1) % 1000 == 0) begin
                $display("  Completed %0d random tests...", i + 1);
            end
        end

        // Final report
        sb.report();
        $finish;
    end

endmodule
