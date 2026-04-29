// apb_top.sv
// APB bridge plus GPIO0 and timer peripherals.

`timescale 1ns/1ps

module apb_top(
    input  logic        clk,
    input  logic        reset,

    input  logic        req_valid,
    input  logic [31:0] req_addr,
    input  logic [31:0] req_wdata,
    input  logic [3:0]  req_wmask,

    output logic        busy,
    output logic        resp_valid,
    output logic [31:0] resp_rdata,

    input  logic [7:0]  gpio0_in,
    output logic [7:0]  gpio0_out
);

    localparam logic [31:0] APB_BASE       = 32'h0004_0000;
    localparam logic [31:0] APB_LIMIT      = 32'h0004_07FF;
    localparam logic [31:0] APB_SLOT_STRIDE = 32'h0000_0100;
    localparam logic [31:0] APB_GPIO0_BASE = APB_BASE + (0 * APB_SLOT_STRIDE);
    localparam logic [31:0] APB_TIMER_BASE = APB_BASE + (1 * APB_SLOT_STRIDE);

    logic [31:0] apb_paddr;
    logic [31:0] apb_pwdata;
    logic [31:0] apb_prdata;
    logic        apb_pwrite;
    logic        apb_psel;
    logic        apb_penable;
    logic        apb_pready;
    logic        apb_pslverr;

    logic        psel_gpio0;
    logic        psel_timer;
    logic [31:0] gpio0_prdata;
    logic        gpio0_pready;
    logic        gpio0_pslverr;
    logic [31:0] timer_prdata;
    logic        timer_pready;
    logic        timer_pslverr;
    logic [31:0] timer_count;
    logic        timer_running;
    logic        timer_done;
    logic        apb_in_range;

    assign apb_in_range = (req_addr >= APB_BASE) && (req_addr <= APB_LIMIT);

    mem_to_apb_bridge apb_bridge(
        .clk(clk),
        .reset(reset),
        .req_valid(req_valid && apb_in_range),
        .req_addr(req_addr),
        .req_wdata(req_wdata),
        .req_wmask(req_wmask),
        .busy(busy),
        .resp_valid(resp_valid),
        .resp_rdata(resp_rdata),
        .paddr(apb_paddr),
        .pwdata(apb_pwdata),
        .pwrite(apb_pwrite),
        .psel(apb_psel),
        .penable(apb_penable),
        .prdata(apb_prdata),
        .pready(apb_pready),
        .pslverr(apb_pslverr)
    );

    assign psel_gpio0 = apb_psel && (apb_paddr[31:8] == APB_GPIO0_BASE[31:8]);
    assign psel_timer = apb_psel && (apb_paddr[31:8] == APB_TIMER_BASE[31:8]);

    apb_gpio gpio0_inst(
        .clk(clk),
        .reset(reset),
        .paddr(apb_paddr),
        .pwdata(apb_pwdata),
        .psel(psel_gpio0),
        .penable(apb_penable),
        .pwrite(apb_pwrite),
        .prdata(gpio0_prdata),
        .pready(gpio0_pready),
        .pslverr(gpio0_pslverr),
        .gpio_in(gpio0_in),
        .gpio_out(gpio0_out)
    );

    apb_timer timer0_inst(
        .clk(clk),
        .reset(reset),
        .paddr(apb_paddr),
        .pwdata(apb_pwdata),
        .psel(psel_timer),
        .penable(apb_penable),
        .pwrite(apb_pwrite),
        .prdata(timer_prdata),
        .pready(timer_pready),
        .pslverr(timer_pslverr),
        .timer_count(timer_count),
        .timer_running(timer_running),
        .timer_done(timer_done)
    );

    always_comb begin
        apb_prdata  = 32'h0000_0000;
        apb_pready  = 1'b1;
        apb_pslverr = 1'b0;

        case (1'b1)
            psel_gpio0: begin
                apb_prdata  = gpio0_prdata;
                apb_pready  = gpio0_pready;
                apb_pslverr = gpio0_pslverr;
            end
            psel_timer: begin
                apb_prdata  = timer_prdata;
                apb_pready  = timer_pready;
                apb_pslverr = timer_pslverr;
            end
            default: begin
                apb_prdata  = 32'h0000_0000;
                apb_pready  = 1'b1;
                apb_pslverr = 1'b0;
            end
        endcase
    end

endmodule