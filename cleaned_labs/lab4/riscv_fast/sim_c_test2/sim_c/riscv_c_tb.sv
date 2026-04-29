// riscv_c_tb.sv
// Testbench for C program simulation - checks result at address 4092 (word address 1023)

`timescale 1ns/1ps

module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;

  // Expected result from test1: y = func(2, 3) = 2 << 3 = 16
  localparam EXPECTED_RESULT = 32'd16;
  localparam RESULT_ADDR = 32'd4092;  // Byte address 4092 (word address 1023)

  // instantiate device to be tested
  riscv_top_c dut(clk, reset, WriteData, DataAdr, MemWrite);

  // initialize test
  initial
    begin
      reset <= 1; # 22; reset <= 0; # 22; reset <= 1;
    end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  // check results - monitors the write to final address
  always @(negedge clk)
    begin
      if(MemWrite) begin
        if(DataAdr === RESULT_ADDR) begin
          if(WriteData === EXPECTED_RESULT) begin
            $display("Memory[4092] = %d (0x%08h)", WriteData, WriteData);
            $display("Simulation succeeded - C program result correct!");
            $finish;
          end else begin
            $display("Simulation failed - wrote %d to address %d, expected %d",
                     WriteData, DataAdr, EXPECTED_RESULT);
            $finish;
          end
        end else begin
          $display("Write to address %d (0x%08h) with data %d (0x%08h)",
                   DataAdr, DataAdr, WriteData, WriteData);
        end
      end
    end

    // Add timeout to prevent infinite simulation
    initial begin
      #10000;  // Increased timeout for larger program
      $display("Simulation timeout - test may be stuck");
      $finish;
    end
endmodule
