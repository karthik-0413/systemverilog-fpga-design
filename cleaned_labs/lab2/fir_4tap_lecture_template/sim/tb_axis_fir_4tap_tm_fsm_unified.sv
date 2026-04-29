`timescale 1ns / 1ps

/**
 * Testbench for 4-Tap Parallel FIR Filter (Unified FSM Version)
 * Refactored to use Transaction-based driving and monitoring.
 */

module tb_axis_fir_4tap_tm_fsm_unified;

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
    // DUT Instantiation
    // ========================================================================

    axis_fir_4tap_tm_fsm_unified dut (
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
    // Virtual Interfaces (to support class-based tasks)
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
                $display("[PASS] Output[%0d]: received=%0d, expected=%0d, TLAST=%b",
                         index, received, expected, tr.last);
            end else begin
                fail_count++;
                $display("[FAIL] Output[%0d]: received=%0d, expected=%0d, TLAST=%b",
                         index, received, expected, tr.last);
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
    // Test Stimulus
    // ========================================================================

    Scoreboard sb_coeff;
    Scoreboard sb_data;
    Scoreboard sb_backpressure;
    logic      sb_backpressure_done;

    // Cycle-by-cycle signal monitor for debugging
    initial begin
        @(posedge aresetn);
        forever @(posedge aclk) begin
            if (m_axis_tvalid || s_axis_tvalid)
                $display("  [CYCLE] S: valid=%b data=%0d last=%b ready=%b | M: valid=%b data=%0d last=%b ready=%b",
                         s_axis_tvalid, s_axis_tdata[15:0], s_axis_tlast, s_axis_tready,
                         m_axis_tvalid, m_axis_tdata[15:0], m_axis_tlast, m_axis_tready);
        end
    end

    initial begin
        // Initialize
        s_if.tdata  = 32'h0;
        s_if.tvalid = 1'b0;
        s_if.tlast  = 1'b0;
        m_if.tready = 1'b1;
        stream_load_coeff_en = 1'b0;
        sb_backpressure_done = 1'b0;

        // Wait for reset
        @(posedge aresetn);
        repeat(5) @(posedge aclk);

        // Test 1: Coefficient Loading
        $display("\n========================================");
        $display("  Test 1: Coefficient Loading");
        $display("========================================");

        stream_load_coeff_en = 1'b1;
        sb_coeff = new();
        sb_coeff.add_expected(16'd1); sb_coeff.add_expected(16'd2);
        sb_coeff.add_expected(16'd3); sb_coeff.add_expected(16'd4);

        fork
            begin
                AXI_Transaction tr;
                for (int i = 0; i < 4; i++) begin
                    tr = new();
                    tr.data = i + 1;
                    tr.last = (i == 3);
                    tr.delay = 0;  // ← ZERO DELAY to reproduce hardware DMA behavior!
                    tr.drive(s_if);
                end
            end
            begin
                AXI_Transaction tr;
                int output_count = 0;
                logic last_seen = 0;
                // Monitor ALL outputs until TLAST is seen
                while (!last_seen) begin
                    tr = new();
                    tr.monitor(m_if);
                    $display("[COEFF OUT] index=%0d, data=%0d, TLAST=%b",
                             output_count, tr.data[15:0], tr.last);
                    sb_coeff.check(tr, output_count);  // ← NOW VALIDATES VALUES!
                    last_seen = tr.last;
                    output_count++;
                end
                $display(">>> Total coefficient outputs: %0d (expected 4)", output_count);
                if (output_count != 4)
                    $display(">>> ERROR: Expected 4 outputs, got %0d!", output_count);
            end
        join
        sb_coeff.report();

        // ====================================================================
        // Test 2: Data Filtering
        // ====================================================================
        $display("\n========================================");
        $display("  Test 2: Data Filtering");
        $display("========================================");

        stream_load_coeff_en = 1'b0;
        sb_data = new();
        sb_data.add_expected(16'd200); sb_data.add_expected(16'd300);
        sb_data.add_expected(16'd400); sb_data.add_expected(16'd500);
        sb_data.add_expected(16'd600); sb_data.add_expected(16'd700);

        fork
            begin
                AXI_Transaction tr;
                logic [15:0] inputs[] = '{10, 20, 30, 40, 50, 60, 70, 80, 90};
                for (int i = 0; i < 9; i++) begin
                    tr = new();
                    tr.data = inputs[i];
                    tr.last = (i == 8);
                    tr.delay = $urandom_range(0, 5);
                    tr.drive(s_if);
                end
            end
            begin
                AXI_Transaction tr;
                for (int i = 0; i < 6; i++) begin
                    tr = new();
                    tr.monitor(m_if);
                    sb_data.check(tr, i);
                end
            end
        join
        sb_data.report();

        // ====================================================================
        // Test 3: Backpressure Handling
        // ====================================================================
        $display("\n========================================");
        $display("  Test 3: Backpressure Handling");
        $display("========================================");

        sb_backpressure = new();
        sb_backpressure.add_expected(16'd200); sb_backpressure.add_expected(16'd300);
        sb_backpressure.add_expected(16'd400); sb_backpressure.add_expected(16'd500);
        sb_backpressure.add_expected(16'd600); sb_backpressure.add_expected(16'd700);

        fork
            begin
                while (!sb_backpressure_done) begin
                    @(posedge aclk);
                    m_if.tready <= $random % 2;
                end
                m_if.tready <= 1'b1;
            end
            begin
                AXI_Transaction tr;
                logic [15:0] inputs[] = '{10, 20, 30, 40, 50, 60, 70, 80, 90};
                for (int i = 0; i < 9; i++) begin
                    tr = new();
                    tr.data = inputs[i];
                    tr.last = (i == 8);
                    tr.delay = $urandom_range(0, 5);
                    tr.drive(s_if);
                end
            end
            begin
                AXI_Transaction tr;
                for (int i = 0; i < 6; i++) begin
                    tr = new();
                    tr.monitor(m_if);
                    sb_backpressure.check(tr, i);
                end
                sb_backpressure_done = 1'b1;
            end
        join
        sb_backpressure.report();

        $display("\n========================================");
        $display("  All Tests Complete!");
        $display("========================================\n");
        repeat(10) @(posedge aclk);
        $finish;
    end

endmodule
