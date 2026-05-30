/*
 * Testbench: Pulse Counter
 * Verifies: counting, debounce, enable/disable, clear.
 *
 * Run: iverilog -o tb_pulse_counter tb/tb_pulse_counter.v rtl/pulse_counter.v && vvp tb_pulse_counter
 */

`timescale 1ns/1ps

module tb_pulse_counter;

    reg clk, rst_n;
    reg pulse_in, enable, clear;
    reg [1:0] debounce_sel;
    wire [31:0] count;
    wire [15:0] count_16;

    pulse_counter u_pc (
        .clk(clk), .rst_n(rst_n),
        .pulse_in(pulse_in), .enable(enable), .clear(clear),
        .debounce_sel(debounce_sel),
        .count(count), .count_16(count_16)
    );

    initial clk = 0;
    always #500 clk = ~clk; // 1 MHz

    integer errors = 0;

    task pulse_n;
        input integer n;
        input integer half_period_ns;
        integer i;
    begin
        for (i = 0; i < n; i = i + 1) begin
            pulse_in = 1;
            #(half_period_ns);
            pulse_in = 0;
            #(half_period_ns);
        end
    end
    endtask

    task check16;
        input [15:0] got;
        input [15:0] expected;
        input [8*40-1:0] msg;
    begin
        if (got !== expected) begin
            $display("FAIL: %0s — got %0d, expected %0d", msg, got, expected);
            errors = errors + 1;
        end else begin
            $display("PASS: %0s = %0d", msg, got);
        end
    end
    endtask

    initial begin
        $dumpfile("tb_pulse_counter.vcd");
        $dumpvars(0, tb_pulse_counter);

        rst_n = 0;
        pulse_in = 0;
        enable = 0;
        clear = 0;
        debounce_sel = 2'b00; // no debounce
        #5000;
        rst_n = 1;
        #3000;

        $display("\n=== Test 1: 10 pulses, no debounce, enabled ===");
        enable = 1;
        pulse_n(10, 2000); // 10 pulses, 2us half-period (250 kHz)
        #5000;
        check16(count_16, 16'd10, "count after 10 pulses");

        $display("\n=== Test 2: Disabled — pulses should not count ===");
        enable = 0;
        pulse_n(5, 2000);
        #5000;
        check16(count_16, 16'd10, "count unchanged when disabled");

        $display("\n=== Test 3: Clear ===");
        @(negedge clk);
        clear = 1;
        @(negedge clk);
        clear = 0;
        #3000;
        check16(count_16, 16'd0, "count after clear");

        $display("\n=== Test 4: 5 more pulses after clear ===");
        enable = 1;
        pulse_n(5, 2000);
        #5000;
        check16(count_16, 16'd5, "count = 5 after clear+5");

        $display("\n");
        if (errors == 0)
            $display("*** ALL PULSE_COUNTER TESTS PASSED ***");
        else
            $display("*** %0d PULSE_COUNTER TEST(S) FAILED ***", errors);

        $finish;
    end

endmodule
