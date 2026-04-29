// riscvmulti_tb.sv
// Testbench for RISC-V multicycle processor

`timescale 1ns/1ps

module testbench();

  logic        clk;
  logic        reset;

  logic [31:0] WriteData, DataAdr;
  logic        MemWrite;

  // instantiate device to be tested
  top dut(clk, reset, WriteData, DataAdr, MemWrite);

  // initialize test
  initial
    begin
      reset <= 1; # 22; reset <= 0;
    end

  // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end

  // check results and print memory writes
  always @(negedge clk)
    begin
      if(MemWrite) begin
        $display("Memory write: Address[0x%08h] = 0x%08h (%d)", DataAdr, WriteData, WriteData);
        if(DataAdr === 100 & WriteData === 25) begin
          $display("Simulation succeeded");
          $stop;
        end else if (DataAdr !== 96 & DataAdr !== 100) begin
          $display("Simulation failed: unexpected address");
          $stop;
        end
      end
    end
endmodule
