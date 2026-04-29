// Testbench 2: Constrained Random Testing with Simple Classes
//
// This testbench demonstrates:
//   - Simple SystemVerilog classes for stimulus generation
//   - Constrained random testing
//   - Directed corner case testing
//   - Basic scoreboard checking

`timescale 1ns / 1ps

module tb_adder_constrained_random;

    // Testbench signals
    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] sum;
    logic        carry_out;

    // Instantiate DUT
    adder_16bit dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry_out(carry_out)
    );

    // Simple Transaction Class
    class Transaction;
        rand bit [15:0] a;
        rand bit [15:0] b;
        bit [15:0] sum;
        bit carry_out;

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
            $display("%sTransaction: a=%h, b=%h => sum=%h, carry=%b",
                     prefix, a, b, sum, carry_out);
        endfunction
    endclass

    // Simple Scoreboard Class
    class Scoreboard;
        int pass_count = 0;
        int fail_count = 0;

        function void check(Transaction tr);
            logic [16:0] expected;
            expected = {1'b0, tr.a} + {1'b0, tr.b};

            if (tr.sum === expected[15:0] && tr.carry_out === expected[16]) begin
                pass_count++;
            end else begin
                fail_count++;
                $display("ERROR: Mismatch detected!");
                $display("  Inputs:   a=%h, b=%h", tr.a, tr.b);
                $display("  Expected: sum=%h, carry=%b", expected[15:0], expected[16]);
                $display("  Got:      sum=%h, carry=%b", tr.sum, tr.carry_out);
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
        int num_random_tests = 10000;

        $display("========================================");
        $display("  16-bit Adder Constrained Random Test");
        $display("========================================\n");

        tr = new();
        sb = new();

        // Part 1: Directed Corner Cases
        $display("Part 1: Directed Corner Case Tests\n");

        // Test 1: Both zeros
        a = 16'h0000; b = 16'h0000; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 1: ");
        sb.check(tr);

        // Test 2: Both max
        a = 16'hFFFF; b = 16'hFFFF; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 2: ");
        sb.check(tr);

        // Test 3: One zero, one max
        a = 16'h0000; b = 16'hFFFF; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 3: ");
        sb.check(tr);

        // Test 4: One max, one zero
        a = 16'hFFFF; b = 16'h0000; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 4: ");
        sb.check(tr);

        // Test 5: Carry generation (MSBs set)
        a = 16'h8000; b = 16'h8000; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 5: ");
        sb.check(tr);

        // Test 6: No carry (small values)
        a = 16'h0001; b = 16'h0001; #10;
        tr.a = a; tr.b = b; tr.sum = sum; tr.carry_out = carry_out;
        tr.display("  Corner case 6: ");
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
            #10;

            // Capture outputs
            tr.sum = sum;
            tr.carry_out = carry_out;

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
