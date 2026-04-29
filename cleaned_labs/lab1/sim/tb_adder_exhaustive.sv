// Testbench 1: Exhaustive Testing with Simple Driver/Monitor/Scoreboard
//
// This testbench demonstrates:
//   - Driver: Applies input combinations exhaustively
//   - Monitor: Observes outputs
//   - Scoreboard: Checks correctness against expected results
//
// No classes used - simple procedural approach for clarity
//
// NOTE: To test all 2^32 combinations, change MAXVAL to 65536 (warning: very slow!)
//       Current setting tests 2^16 combinations for quick verification

`timescale 1ns / 1ps

module tb_adder_exhaustive;

    // TEST RANGE: Change this to test more combinations
    // 256 = 2^16 tests (quick, ~1 second)
    // 1024 = 2^20 tests (~10 seconds)
    // 65536 = 2^32 tests (VERY slow, hours!)
    localparam int MAXVAL = 256;
    //localparam int MAXVAL = 4096;
    //localparam longint MAXVAL = 65536;

    // Testbench signals
    logic [15:0] a;
    logic [15:0] b;
    logic [15:0] sum;
    logic        carry_out;

    // Scoreboard variables
    logic [16:0] expected_result;
    logic [15:0] expected_sum;
    logic        expected_carry;
    longint          test_count;
    int          pass_count;
    int          fail_count;

    // Instantiate DUT (Device Under Test)
    adder_16bit dut (
        .a(a),
        .b(b),
        .sum(sum),
        .carry_out(carry_out)
    );

    // Driver + Monitor + Scoreboard combined
    initial begin
        $display("========================================");
        $display("  16-bit Adder Exhaustive Test");
        $display("========================================");
        $display("Testing %0d x %0d = %0d combinations", MAXVAL, MAXVAL, MAXVAL*MAXVAL);
        $display("(To test all 2^32, change MAXVAL to 65536)\n");

        test_count = 0;
        pass_count = 0;
        fail_count = 0;

        // Driver: Apply all possible input combinations
        for (int i = 0; i < MAXVAL; i++) begin
            for (int j = 0; j < MAXVAL; j++) begin
                // Drive inputs
                a = i[15:0];
                b = j[15:0];
                #10;  // Wait for combinational logic to settle

                // Scoreboard: Calculate expected result
                expected_result = {1'b0, a} + {1'b0, b};
                expected_sum = expected_result[15:0];
                expected_carry = expected_result[16];

                // Monitor + Scoreboard: Check outputs
                test_count++;
                if (sum === expected_sum && carry_out === expected_carry) begin
                    pass_count++;
                end else begin
                    fail_count++;
                    $display("ERROR at test %0d: a=%h, b=%h", test_count, a, b);
                    $display("  Expected: sum=%h, carry=%b", expected_sum, expected_carry);
                    $display("  Got:      sum=%h, carry=%b", sum, carry_out);
                end

                // Progress update every 10M tests
                if (test_count % 10000000 == 0) begin
                    $display("Progress: %0d million tests out of %0d completed", test_count / 1000000, MAXVAL*MAXVAL / 1000000);
                end
            end
        end

        // Final report
        $display("\n========================================");
        $display("  Test Summary");
        $display("========================================");
        $display("Total tests:  %0d", test_count);
        $display("Passed:       %0d", pass_count);
        $display("Failed:       %0d", fail_count);
        $display("Pass rate:    %0.2f%%", (pass_count * 100.0) / test_count);

        if (fail_count == 0) begin
            $display("\n*** ALL TESTS PASSED! ***");
        end else begin
            $display("\n*** SOME TESTS FAILED! ***");
        end

        $display("========================================\n");
        $finish;
    end

endmodule
