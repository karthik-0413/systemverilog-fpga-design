// riscv_apb_tb.sv
// Testbench for APB GPIO0 plus timer simulation.

`timescale 1ns/1ps

module testbench();

    function automatic string apb_state_name(logic state_bit);
        if (state_bit == 1'b0) begin
            return "IDLE_SETUP";
        end
        return "ACCESS";
    endfunction

    logic        clk;
    logic        reset;
    logic [7:0]  gpio0_in;
    logic [7:0]  gpio0_out;
    logic [31:0] WriteData;
    logic [31:0] DataAdr;
    logic        MemWrite;

    localparam logic [31:0] RESULT_ADDR     = 32'd4092;
    localparam logic [31:0] EXPECTED_RESULT  = 32'h00C0FFEE;

    riscv_top dut(
        .clk(clk),
        .reset(reset),
        .gpio0_in(gpio0_in),
        .gpio0_out(gpio0_out),
        .WriteData(WriteData),
        .DataAdr(DataAdr),
        .MemWrite(MemWrite)
    );

    logic [7:0] prev_gpio0_out;
    logic [31:0] prev_timer_count;
    bit         prev_ready;
    bit         pass;

    initial begin
        clk = 1'b0;
        reset = 1'b0;
        gpio0_in = 8'hA5;
        prev_gpio0_out = 8'h00;
        prev_timer_count = 32'hFFFF_FFFF;
        prev_ready = 1'b0;
        pass = 1'b0;

        $display("Expected behavior reference:");
        $display("  GPIO0 input = 0x%02h", gpio0_in);
        $display("  Timer prescaler = 0, limit = 8, then start and poll done");
        $display("  Program ends by writing 0x%08h to 0x%08h", EXPECTED_RESULT, RESULT_ADDR);

        #22 reset = 1'b1;
    end

    always begin
        #5 clk = ~clk;
    end

    always @(negedge clk) begin
        #1;

        if (!reset) begin
            prev_gpio0_out = 8'h00;
            prev_ready = 1'b0;
        end else begin
            if (dut.apb_subsystem.apb_psel || dut.apb_subsystem.apb_penable || dut.apb_subsystem.resp_valid) begin
                $display("  >> APB state=%s psel=%0b penable=%0b pwrite=%0b paddr=0x%08h pwdata=0x%08h prdata=0x%08h pready=%0b pslverr=%0b",
                         apb_state_name(dut.apb_subsystem.apb_bridge.state),
                         dut.apb_subsystem.apb_psel, dut.apb_subsystem.apb_penable, dut.apb_subsystem.apb_pwrite,
                         dut.apb_subsystem.apb_paddr, dut.apb_subsystem.apb_pwdata, dut.apb_subsystem.apb_prdata,
                         dut.apb_subsystem.apb_pready, dut.apb_subsystem.apb_pslverr);
            end

            if (!prev_ready) begin
                prev_gpio0_out = gpio0_out;
                prev_ready = 1'b1;
            end else begin
                if (gpio0_out !== prev_gpio0_out) begin
                    $display("      GPIO0 out changed: 0x%02h -> 0x%02h", prev_gpio0_out, gpio0_out);
                    prev_gpio0_out = gpio0_out;
                end

                if (dut.apb_subsystem.timer_running) begin
                    if (dut.apb_subsystem.timer_count !== prev_timer_count) begin
                        $display("      TIMER count=%0d status=0x%08h", dut.apb_subsystem.timer_count, dut.apb_subsystem.timer_done ? 32'h0000_0002 : 32'h0000_0001);
                        prev_timer_count = dut.apb_subsystem.timer_count;
                    end
                end else begin
                    prev_timer_count = 32'hFFFF_FFFF;
                end
            end

            if (MemWrite && DataAdr === RESULT_ADDR) begin
                if (WriteData === EXPECTED_RESULT) begin
                    if (gpio0_out !== gpio0_in) begin
                        $display("Simulation failed - GPIO0 output mismatch: out=0x%02h in=0x%02h.", gpio0_out, gpio0_in);
                        $finish;
                    end
                    $display("Program ended cleanly: wrote 0x%08h to 0x%08h.", WriteData, DataAdr);
                    $finish;
                end else begin
                    $display("Simulation failed - wrote 0x%08h to address 0x%08h, expected 0x%08h.",
                             WriteData, DataAdr, EXPECTED_RESULT);
                    $finish;
                end
            end
        end
    end

    initial begin
        #20000;
        if (!pass) begin
            $display("Simulation timeout - APB test may be stuck");
        end
        $finish;
    end

endmodule
