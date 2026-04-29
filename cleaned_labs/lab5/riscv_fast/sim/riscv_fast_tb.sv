// riscv_fast_tb.sv
// Testbench for RISC-V fast processor with synchronous BRAM

`timescale 1ns/1ps

module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;

  // instantiate device to be tested
  riscv_top dut(clk, reset, WriteData, DataAdr, MemWrite);

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

  // check results - same test as single-cycle version
  always @(negedge clk)
    begin
      if(MemWrite) begin
        if(DataAdr === 100 & WriteData === 25) begin
          $display("Memory[100] = %d (0x%08h)", WriteData, WriteData);
          $display("Simulation succeeded");
          $stop;
        end else if (DataAdr !== 96) begin
          $display("Simulation failed - wrote to address %d with data %d", DataAdr, WriteData);
          $stop;
        end
      end
    end
    
    // Add timeout to prevent infinite simulation
    initial begin
      #10000;
      $display("Simulation timeout - test may be stuck");
      $stop;
    end
endmodule
