`timescale 1ns / 1ps

/**
 * Testbench for 64-Tap Parallel FIR Filter (Unified FSM Version)
 * Based on professor's 4-tap TB structure with AXI_Transaction class,
 * Scoreboard, virtual interfaces, and assertions.
 */

module tb_fir_filter;

    // ========================================================================
    // Test Selection Parameter
    // ========================================================================

    parameter string TEST_MODE;  // "LP", "HP", or "BOTH"

    // ========================================================================
    // Parameters
    // ========================================================================

    parameter NUM_INPUT_SAMPLES = 1000;
    parameter NUM_OUTPUT_SAMPLES = 937;
    parameter NUM_TAPS = 64;

    // ========================================================================
    // Clock and Reset
    // ========================================================================

    logic aclk;
    logic aresetn;

    initial begin
        aclk = 1'b0;
        forever #5 aclk = ~aclk;  // 100 MHz clock
    end

    initial begin
        aresetn = 1'b0;
        #20 aresetn = 1'b1;
    end

    // ========================================================================
    // DUT Signals
    // ========================================================================

    logic        stream_load_coeff_en;
    logic        s_axis_tready;
    logic [31:0] s_axis_tdata;
    logic        s_axis_tvalid;
    logic        s_axis_tlast;
    logic        m_axis_tready;
    logic [31:0] m_axis_tdata;
    logic        m_axis_tvalid;
    logic        m_axis_tlast;

    // ========================================================================
    // Test Data Arrays
    // ========================================================================

    logic signed [15:0] input_data [0:NUM_INPUT_SAMPLES-1];
    logic signed [15:0] lp_coeffs [0:NUM_TAPS-1];
    logic signed [15:0] hp_coeffs [0:NUM_TAPS-1];
    logic signed [15:0] lp_expected_data [0:NUM_OUTPUT_SAMPLES-1];
    logic signed [15:0] hp_expected_data [0:NUM_OUTPUT_SAMPLES-1];

    // ========================================================================
    // DUT Instantiation
    // ========================================================================

    fir_filter_parallel dut (
        .aclk              (aclk),
        .aresetn           (aresetn),
        .stream_load_coeff_en(stream_load_coeff_en),
        .s_axis_tready     (s_axis_tready),
        .s_axis_tdata      (s_axis_tdata),
        .s_axis_tvalid     (s_axis_tvalid),
        .s_axis_tlast      (s_axis_tlast),
        .m_axis_tready     (m_axis_tready),
        .m_axis_tdata      (m_axis_tdata),
        .m_axis_tvalid     (m_axis_tvalid),
        .m_axis_tlast      (m_axis_tlast)
    );

    // ========================================================================
    // Transaction Class
    // ========================================================================

    class AXI_Transaction;
        rand bit [31:0] data;
        rand bit        last;
        rand int        delay;

        constraint delay_c {
            delay dist {0 := 50, [1:3] := 40, [4:10] := 10};
        }

        // Task to drive a single transaction onto the slave interface
        task drive(virtual interface axis_if vif);
            repeat(delay) @(posedge vif.clk);

            vif.tdata  <= data;
            vif.tlast  <= last;
            vif.tvalid <= 1'b1;

            @(posedge vif.clk);
            while (!vif.tready) @(posedge vif.clk);

            vif.tvalid <= 1'b0;
            vif.tlast  <= 1'b0;
        endtask

        // Task to monitor a single transaction from the master interface
        task monitor(virtual interface axis_if vif);
            @(posedge vif.clk);
            while (!(vif.tvalid && vif.tready)) @(posedge vif.clk);

            data = vif.tdata;
            last = vif.tlast;
        endtask

        function void display(string prefix = "");
            $display("%sdata=0x%08h, TLAST=%b, delay=%0d",
                     prefix, data, last, delay);
        endfunction
    endclass

    // ========================================================================
    // Virtual Interfaces
    // ========================================================================

    interface axis_if(input logic clk);
        logic [31:0] tdata;
        logic        tvalid;
        logic        tready;
        logic        tlast;
    endinterface

    axis_if s_if(aclk);
    axis_if m_if(aclk);

    // Connect virtual interfaces to DUT signals
    assign s_axis_tdata  = s_if.tdata;
    assign s_axis_tvalid = s_if.tvalid;
    assign s_if.tready   = s_axis_tready;
    assign s_axis_tlast  = s_if.tlast;

    assign m_if.tdata    = m_axis_tdata;
    assign m_if.tvalid   = m_axis_tvalid;
    assign m_axis_tready = m_if.tready;
    assign m_if.tlast    = m_axis_tlast;

    // ========================================================================
    // Scoreboard Class
    // ========================================================================

    class Scoreboard;
        int pass_count = 0;
        int fail_count = 0;
        logic [15:0] expected_values[$];

        function void add_expected(logic [15:0] value);
            expected_values.push_back(value);
        endfunction

        function void check(AXI_Transaction tr, int index);
            logic [15:0] received = tr.data[15:0];
            logic [15:0] expected;

            if (expected_values.size() == 0) begin
                $display("ERROR: Unexpected output at index %0d", index);
                fail_count++;
                return;
            end

            expected = expected_values.pop_front();

            if (received === expected) begin
                pass_count++;
            end else begin
                fail_count++;
                if (fail_count <= 20)
                    $display("[FAIL] Output[%0d]: received=0x%04h (%0d), expected=0x%04h (%0d), TLAST=%b",
                             index, received, $signed(received), expected, $signed(expected), tr.last);
            end
        endfunction

        function void report(string name = "");
            $display("\n========================================");
            $display("  Scoreboard Summary: %s", name);
            $display("========================================");
            $display("Passed: %0d", pass_count);
            $display("Failed: %0d", fail_count);
            $display("Total:  %0d", pass_count + fail_count);
            if (fail_count == 0)
                $display("\n*** ALL %s TESTS PASSED! ***", name);
            else
                $display("\n*** %s TESTS FAILED! ***", name);
            $display("========================================\n");
        endfunction
    endclass

    // ========================================================================
    // Assertions (on both ports)
    // ========================================================================

    // Slave Port Assertions
    property S_CheckReset; @(posedge aclk) !aresetn |-> !s_axis_tvalid; endproperty
    assert_s_reset: assert property (S_CheckReset) else $error("S_CheckReset failed");

    property S_CheckHoldValid; @(posedge aclk) disable iff (!aresetn) (s_axis_tvalid && !s_axis_tready) |=> s_axis_tvalid; endproperty
    assert_s_hold_valid: assert property (S_CheckHoldValid) else $error("S_CheckHoldValid failed");

    property S_CheckStableData; @(posedge aclk) disable iff (!aresetn) (s_axis_tvalid && !s_axis_tready) |=> $stable(s_axis_tdata); endproperty
    assert_s_stable_data: assert property (S_CheckStableData) else $error("S_CheckStableData failed");

    // Master Port Assertions
    property M_CheckReset; @(posedge aclk) !aresetn |-> !m_axis_tvalid; endproperty
    assert_m_reset: assert property (M_CheckReset) else $error("M_CheckReset failed");

    property M_CheckHoldValid; @(posedge aclk) disable iff (!aresetn) (m_axis_tvalid && !m_axis_tready) |=> m_axis_tvalid; endproperty
    assert_m_hold_valid: assert property (M_CheckHoldValid) else $error("M_CheckHoldValid failed");

    property M_CheckStableData; @(posedge aclk) disable iff (!aresetn) (m_axis_tvalid && !m_axis_tready) |=> $stable(m_axis_tdata); endproperty
    assert_m_stable_data: assert property (M_CheckStableData) else $error("M_CheckStableData failed");

    // ========================================================================
    // Load Test Vectors from Files
    // ========================================================================

    initial begin
        $display("========================================");
        $display("Loading Test Vectors");
        $display("========================================");

        $readmemh("input_signal.mem", input_data);
        $display("Loaded %0d input samples", NUM_INPUT_SAMPLES);

        $readmemh("lp_coeffs.mem", lp_coeffs);
        $display("Loaded %0d LP coefficients", NUM_TAPS);

        $readmemh("hp_coeffs.mem", hp_coeffs);
        $display("Loaded %0d HP coefficients", NUM_TAPS);

        $readmemh("lp_output_expected.mem", lp_expected_data);
        $display("Loaded %0d LP expected outputs", NUM_OUTPUT_SAMPLES);

        $readmemh("hp_output_expected.mem", hp_expected_data);
        $display("Loaded %0d HP expected outputs", NUM_OUTPUT_SAMPLES);

        $display("========================================\n");
    end


    // Debug: show first values after load
    initial begin
        int sum = 0;
        @(posedge aresetn);
        repeat(10) @(posedge aclk);

        // $display("=== LOADED DATA CHECK ===");
        // $display("First 5 LP coefficients:");
        // for (int i = 0; i < 5; i++)
        //     $display("  lp_coeffs[%0d] = 0x%04h", i, lp_coeffs[i]);
        // $display("First 5 input samples:");
        // for (int i = 0; i < 5; i++)
        //     $display("  input_data[%0d] = 0x%04h", i, input_data[i]);
        // $display("First 5 LP expected outputs:");
        // for (int i = 0; i < 5; i++)
        //     $display("  lp_expected[%0d] = 0x%04h", i, lp_expected_data[i]);
        // $display("");

        // $display("=== LOADED DATA CHECK ===");
        // $display("First 5 HP coefficients:");
        // for (int i = 0; i < 5; i++)
        //     $display("  hp_coeffs[%0d] = 0x%04h", i, hp_coeffs[i]);
        // $display("First 5 input samples:");
        // for (int i = 0; i < 5; i++)
        //     $display("  input_data[%0d] = 0x%04h", i, input_data[i]);
        // $display("First 5 LP expected outputs:");
        // for (int i = 0; i < 5; i++)
        //     $display("  hp_expected[%0d] = 0x%04h", i, hp_expected_data[i]);
        // $display("");

        

        for (int i = 0; i < NUM_TAPS; i++)
            sum += lp_coeffs[i];

        $display("LP coefficient sum = %0d", sum);
    end

    // ========================================================================
    // Cycle-by-cycle signal monitor for debugging
    // ========================================================================

    initial begin
        @(posedge aresetn);
        forever @(posedge aclk) begin
            if (m_axis_tvalid || s_axis_tvalid)
                $display("  [CYCLE] S: valid=%b data=0x%04h last=%b ready=%b | M: valid=%b data=0x%04h last=%b ready=%b",
                         s_axis_tvalid, s_axis_tdata[15:0], s_axis_tlast, s_axis_tready,
                         m_axis_tvalid, m_axis_tdata[15:0], m_axis_tlast, m_axis_tready);
        end
    end

    // ========================================================================
    // Test Stimulus
    // ========================================================================

    Scoreboard sb_lp;
    Scoreboard sb_hp;

    initial begin
        // Initialize
        s_if.tdata  = 32'h0;
        s_if.tvalid = 1'b0;
        s_if.tlast  = 1'b0;
        m_if.tready = 1'b1;
        stream_load_coeff_en = 1'b0;

        // Wait for reset
        @(posedge aresetn);
        repeat(5) @(posedge aclk);

        // ==================================================================
        // Test 1: Low-Pass Filter
        // ==================================================================
        if (TEST_MODE == "LP" || TEST_MODE == "BOTH") begin
            $display("\n========================================");
            $display("  Test 1: Low-Pass Filter");
            $display("========================================");

            // ---- Phase 1: Load LP Coefficients ----
            $display("\nPhase 1: Loading LP Coefficients...");
            stream_load_coeff_en = 1'b1;

            fork
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_TAPS; i++) begin
                        tr = new();
                        tr.data = {{16'd0}, lp_coeffs[i]};
                        tr.last = (i == NUM_TAPS - 1);
                        tr.delay = 0;
                        tr.drive(s_if);
                    end
                end
                begin
                    AXI_Transaction tr;
                    int coeff_out_count = 0;
                    logic last_seen = 0;
                    while (!last_seen) begin
                        tr = new();
                        tr.monitor(m_if);
                        last_seen = tr.last;
                        coeff_out_count++;
                    end
                    $display("  Received %0d coefficient echoes (expected %0d)", coeff_out_count, NUM_TAPS);
                end
            join

            $display("  LP coefficients loaded\n");

            // ---- Phase 2: Stream Data and Capture LP Output ----
            $display("Phase 2: Streaming Input Data for LP filter...");
            stream_load_coeff_en = 1'b0;

            sb_lp = new();
            for (int i = 0; i < NUM_OUTPUT_SAMPLES; i++)
                sb_lp.add_expected(lp_expected_data[i]);

            fork
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_INPUT_SAMPLES; i++) begin
                        tr = new();
                        tr.data = {{16'd0}, input_data[i]};
                        tr.last = (i == NUM_INPUT_SAMPLES - 1);
                        tr.delay = 0;
                        tr.drive(s_if);
                    end
                end
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_OUTPUT_SAMPLES; i++) begin
                        tr = new();
                        tr.monitor(m_if);
                        sb_lp.check(tr, i);
                    end
                end
            join

            sb_lp.report("LP Filter");

            repeat(20) @(posedge aclk);
        end


        // ==================================================================
        // Test 2: High-Pass Filter
        // ==================================================================
        if (TEST_MODE == "HP" || TEST_MODE == "BOTH") begin
            $display("\n========================================");
            $display("  Test 2: High-Pass Filter");
            $display("========================================");

            // ---- Phase 1: Load HP Coefficients ----
            $display("\nPhase 1: Loading HP Coefficients...");
            stream_load_coeff_en = 1'b1;

            fork
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_TAPS; i++) begin
                        tr = new();
                        tr.data = {{16'd0}, hp_coeffs[i]};
                        tr.last = (i == NUM_TAPS - 1);
                        tr.delay = 0;
                        tr.drive(s_if);
                    end
                end
                begin
                    AXI_Transaction tr;
                    int coeff_out_count = 0;
                    logic last_seen = 0;
                    while (!last_seen) begin
                        tr = new();
                        tr.monitor(m_if);
                        last_seen = tr.last;
                        coeff_out_count++;
                    end
                    $display("  Received %0d coefficient echoes (expected %0d)", coeff_out_count, NUM_TAPS);
                end
            join

            $display("  HP coefficients loaded\n");

            // ---- Phase 2: Stream Data and Capture HP Output ----
            $display("Phase 2: Streaming Input Data for HP filter...");
            stream_load_coeff_en = 1'b0;

            sb_hp = new();
            for (int i = 0; i < NUM_OUTPUT_SAMPLES; i++)
                sb_hp.add_expected(hp_expected_data[i]);

            fork
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_INPUT_SAMPLES; i++) begin
                        tr = new();
                        tr.data = {{16'd0}, input_data[i]};
                        tr.last = (i == NUM_INPUT_SAMPLES - 1);
                        tr.delay = 0;
                        tr.drive(s_if);
                    end
                end
                begin
                    AXI_Transaction tr;
                    for (int i = 0; i < NUM_OUTPUT_SAMPLES; i++) begin
                        tr = new();
                        tr.monitor(m_if);
                        sb_hp.check(tr, i);
                    end
                end
            join

            sb_hp.report("HP Filter");

            repeat(20) @(posedge aclk);
        end

        // ==================================================================
        // Final Summary
        // ==================================================================
        $display("\n========================================");
        $display("  All Tests Complete!");
        $display("========================================\n");
        repeat(10) @(posedge aclk);
        $finish;
    end

    // ========================================================================
    // Timeout Watchdog
    // ========================================================================

    initial begin
        #50000000;  // 50ms timeout
        $display("\n========================================");
        $display("ERROR: Simulation timeout!");
        $display("  current DUT state = %0d", dut.current_state);
        $display("  stream_load_coeff_en = %b", stream_load_coeff_en);
        $display("========================================");
        $finish;
    end

endmodule