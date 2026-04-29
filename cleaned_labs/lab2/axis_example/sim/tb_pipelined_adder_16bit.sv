`timescale 1ns/1ps

module tb_pipelined_adder_16bit;

    // Testbench parameters
    parameter CLK_PERIOD = 10;  // 100 MHz clock
    parameter NUM_SAMPLES = 32;
    parameter C1_VALUE = 16'h0100;
    parameter C2_VALUE = 16'h0200;

    // Clock and reset
    logic aclk;
    logic aresetn;

    // DUT signals
    logic         s_axis_tready;
    logic [31:0]  s_axis_tdata;
    logic         s_axis_tvalid;
    logic         s_axis_tlast;
    logic         m_axis_tready;
    logic [31:0]  m_axis_tdata;
    logic         m_axis_tvalid;
    logic         m_axis_tlast;

    // c1 and c2 inputs
    logic [15:0] c1;
    logic [15:0] c2;

    // Testbench variables
    logic [15:0] input_data [0:NUM_SAMPLES-1];
    logic [15:0] expected_data [0:NUM_SAMPLES-1];
    int input_index;
    int output_index;
    int error_count;
    int success_count;

    // Instantiate DUT
    pipelined_adder_16bit dut (
        .aclk(aclk),
        .aresetn(aresetn),
        .c1(c1),
        .c2(c2),
        .s_axis_tready(s_axis_tready),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tlast(m_axis_tlast)
    );

    // Clock generation
    initial begin
        aclk = 0;
        forever #(CLK_PERIOD/2) aclk = ~aclk;
    end

    // Read input and expected data from files
    initial begin
        $display("========================================");
        $display("Pipelined Adder 16-bit Testbench");
        $display("========================================");
        $display("Loading input data from input_data.txt...");
        $readmemh("input_data.txt", input_data);
        $display("Loaded %0d input samples", NUM_SAMPLES);
        
        $display("Loading expected output from expected_output.txt...");
        $readmemh("expected_output.txt", expected_data);
        $display("Loaded %0d expected output samples", NUM_SAMPLES);
        $display("========================================");
    end

    // AXI Stream Master (Input) - drives s_axis_*
    initial begin
        // Initialize signals
        s_axis_tvalid = 0;
        s_axis_tdata = 0;
        s_axis_tlast = 0;
        input_index = 0;
        output_index = 0;
        error_count = 0;
        success_count = 0;

        // Apply reset
        aresetn = 0;
        repeat(5) @(posedge aclk);
        aresetn = 1;
        repeat(2) @(posedge aclk);

        // Set c1 and c2 constants
        c1 = C1_VALUE;
        c2 = C2_VALUE;
        $display("Set c1 = 0x%04h, c2 = 0x%04h", c1, c2);
        $display("Total addition = 0x%04h", c1 + c2);
        $display("========================================");

        // Wait for DUT to be ready
        @(posedge aclk);
        while (!s_axis_tready) begin
            @(posedge aclk);
        end

        // Send all input samples
        $display("Starting AXI Stream transactions...");
        $display("Time    | Direction | Data (hex) | TLAST | Index");
        $display("--------|-----------|------------|-------|-------");
        
        for (input_index = 0; input_index < NUM_SAMPLES; input_index++) begin
            // Wait for ready
            while (!s_axis_tready) begin
                @(posedge aclk);
            end
            
            // Drive data and valid
            s_axis_tdata = {16'h0000, input_data[input_index]};
            s_axis_tvalid = 1;
            s_axis_tlast = (input_index == NUM_SAMPLES - 1);
            
            // Log input transaction
            $display("%0t | INPUT     | 0x%08h | %b     | %0d", 
                     $time, s_axis_tdata, s_axis_tlast, input_index);
            
            @(posedge aclk);
            
            // Deassert valid after one cycle
            s_axis_tvalid = 0;
            s_axis_tlast = 0;
        end

        // Wait for pipeline to flush
        $display("========================================");
        $display("All input samples sent. Waiting for output...");
        $display("========================================");
        
        // Wait for all outputs to be received
        wait(output_index == NUM_SAMPLES);
        
        // Final results
        $display("========================================");
        $display("Test Summary:");
        $display("  Total samples: %0d", NUM_SAMPLES);
        $display("  Successes: %0d", success_count);
        $display("  Errors: %0d", error_count);
        if (error_count == 0) begin
            $display("  Status: PASSED - All outputs match expected values!");
        end else begin
            $display("  Status: FAILED - %0d mismatches detected!", error_count);
        end
        $display("========================================");
        
        // End simulation
        repeat(10) @(posedge aclk);
        $finish;
    end

    // AXI Stream Slave (Output) - monitors m_axis_*
    initial begin
        m_axis_tready = 1;  // Always ready to accept data
        
        forever begin
            @(posedge aclk);
            
            // Check for valid output
            if (m_axis_tvalid && m_axis_tready) begin
                logic [15:0] received_data;
                logic [15:0] expected;
                
                // Extract lower 16 bits (sign-extended result)
                received_data = m_axis_tdata[15:0];
                expected = expected_data[output_index];
                
                // Log output transaction
                $display("%0t | OUTPUT    | 0x%08h | %b     | %0d", 
                         $time, m_axis_tdata, m_axis_tlast, output_index);
                
                // Check TLAST for last sample
                if (output_index == NUM_SAMPLES - 1) begin
                    if (m_axis_tlast) begin
                        $display("  [INFO] TLAST correctly asserted for last sample");
                    end else begin
                        $display("  [ERROR] TLAST not asserted for last sample!");
                        error_count++;
                    end
                end else begin
                    if (m_axis_tlast) begin
                        $display("  [ERROR] TLAST asserted prematurely at index %0d!", output_index);
                        error_count++;
                    end
                end
                
                // Check data against expected
                if (received_data === expected) begin
                    $display("  [PASS] Received 0x%04h, Expected 0x%04h", received_data, expected);
                    success_count++;
                end else begin
                    $display("  [FAIL] Received 0x%04h, Expected 0x%04h", received_data, expected);
                    error_count++;
                end
                
                output_index++;
            end
        end
    end

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("========================================");
        $display("ERROR: Simulation timeout!");
        $display("========================================");
        $finish;
    end

endmodule
