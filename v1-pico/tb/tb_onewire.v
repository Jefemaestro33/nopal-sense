/*
 * Copyright (c) 2026 @Jefemaestro33
 * SPDX-License-Identifier: Apache-2.0
 *
 * Testbench for onewire_master.v
 * Simulates a DS18B20-like device on the 1-Wire bus.
 */

`timescale 1us / 1ns

module tb_onewire;

    reg         clk;
    reg         rst_n;

    // 1-Wire bus (active-low, open-drain with pullup)
    wire        ow_bus;        // actual bus level
    wire        ow_out;
    wire        ow_oe;
    reg         device_drive;  // simulated device pulling low
    wire        ow_in;

    // Command interface
    reg         cmd_valid;
    reg  [2:0]  cmd_op;
    reg  [7:0]  cmd_wdata;
    wire [7:0]  cmd_rdata;
    wire        cmd_done;
    wire        cmd_error;
    wire        presence;

    // Open-drain bus model: pulled high by resistor unless someone pulls low
    assign ow_bus = (ow_oe || device_drive) ? 1'b0 : 1'b1;
    assign ow_in = ow_bus;

    // DUT
    onewire_master #(
        .CLK_FREQ(1_000_000)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .ow_in(ow_in),
        .ow_out(ow_out),
        .ow_oe(ow_oe),
        .cmd_valid(cmd_valid),
        .cmd_op(cmd_op),
        .cmd_wdata(cmd_wdata),
        .cmd_rdata(cmd_rdata),
        .cmd_done(cmd_done),
        .cmd_error(cmd_error),
        .presence(presence)
    );

    // Clock: 1 MHz (1 µs period)
    initial clk = 0;
    always #0.5 clk = ~clk;

    // Test control
    integer test_num;
    integer pass_count;
    integer fail_count;

    // Simulated DS18B20 device behavior
    reg [7:0] device_scratchpad [0:8];
    reg device_present;

    initial begin
        device_present = 1;
        // Simulated scratchpad: temperature = 25.0625°C = 0x0191
        device_scratchpad[0] = 8'h91;  // Temp LSB
        device_scratchpad[1] = 8'h01;  // Temp MSB
        device_scratchpad[2] = 8'h4B;  // TH
        device_scratchpad[3] = 8'h46;  // TL
        device_scratchpad[4] = 8'h7F;  // Config (12-bit)
        device_scratchpad[5] = 8'hFF;  // Reserved
        device_scratchpad[6] = 8'h00;  // Reserved
        device_scratchpad[7] = 8'h10;  // Reserved
        device_scratchpad[8] = 8'hCE;  // CRC
    end

    // Task: simulate presence pulse (device pulls low 60-240 µs after reset release)
    task simulate_presence;
        begin
            // Wait for master to release (ow_oe goes low after reset)
            @(negedge ow_oe);
            // Device waits 15-60 µs then pulls low for 60-240 µs
            #30;  // wait 30 µs
            if (device_present) begin
                device_drive = 1;  // pull low
                #120;              // hold for 120 µs
                device_drive = 0;  // release
            end
        end
    endtask

    // Task: simulate device responding to a read slot (sends a bit)
    task simulate_read_bit;
        input bit_val;
        begin
            // Wait for master to initiate read (pulls low)
            @(posedge ow_oe);
            // Wait for master to release
            @(negedge ow_oe);
            // If sending 0, device pulls low for the slot duration
            if (!bit_val) begin
                device_drive = 1;
                #45;  // hold low for remainder of slot
                device_drive = 0;
            end
            // If sending 1, device does nothing (bus stays high via pullup)
        end
    endtask

    // Task: simulate device responding to read byte
    task simulate_read_byte;
        input [7:0] data;
        integer i;
        begin
            for (i = 0; i < 8; i = i + 1) begin
                simulate_read_bit(data[i]);  // LSB first
            end
        end
    endtask

    // Task: issue command and wait for done
    task issue_cmd;
        input [2:0] op;
        input [7:0] wdata;
        begin
            @(posedge clk);
            cmd_op    = op;
            cmd_wdata = wdata;
            cmd_valid = 1;
            @(posedge clk);
            cmd_valid = 0;
            // Wait for done
            wait(cmd_done == 1);
            @(posedge clk);
        end
    endtask

    // Main test sequence
    initial begin
        // Init
        rst_n = 0;
        cmd_valid = 0;
        cmd_op = 0;
        cmd_wdata = 0;
        device_drive = 0;
        pass_count = 0;
        fail_count = 0;
        test_num = 0;

        // Reset
        #10;
        rst_n = 1;
        #5;

        // ===== TEST 1: Reset + Presence Detect (device present) =====
        test_num = 1;
        fork
            issue_cmd(3'd0, 8'd0);  // OP_RESET
            simulate_presence;
        join
        if (presence && !cmd_error) begin
            $display("PASS [%0d] Reset + presence detected", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [%0d] Reset + presence: presence=%b error=%b", test_num, presence, cmd_error);
            fail_count = fail_count + 1;
        end

        #100;

        // ===== TEST 2: Write byte (0xCC = Skip ROM) =====
        test_num = 2;
        issue_cmd(3'd1, 8'hCC);  // OP_WRITE_BYTE, data = 0xCC
        if (cmd_done) begin
            $display("PASS [%0d] Write byte 0xCC completed", test_num);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [%0d] Write byte did not complete", test_num);
            fail_count = fail_count + 1;
        end

        #100;

        // ===== TEST 3: Read byte (device sends 0x91 = temp LSB) =====
        test_num = 3;
        fork
            issue_cmd(3'd2, 8'd0);  // OP_READ_BYTE
            simulate_read_byte(8'h91);
        join
        if (cmd_rdata == 8'h91) begin
            $display("PASS [%0d] Read byte = 0x%02H (expected 0x91)", test_num, cmd_rdata);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [%0d] Read byte = 0x%02H (expected 0x91)", test_num, cmd_rdata);
            fail_count = fail_count + 1;
        end

        #100;

        // ===== TEST 4: Reset without device (no presence) =====
        test_num = 4;
        device_present = 0;
        issue_cmd(3'd0, 8'd0);  // OP_RESET — no fork, device won't respond
        if (!presence && cmd_error) begin
            $display("PASS [%0d] No device: presence=%b error=%b", test_num, presence, cmd_error);
            pass_count = pass_count + 1;
        end else begin
            $display("FAIL [%0d] No device: presence=%b error=%b", test_num, presence, cmd_error);
            fail_count = fail_count + 1;
        end

        // ===== SUMMARY =====
        #100;
        $display("");
        $display("*** %0d/%0d tests passed ***", pass_count, pass_count + fail_count);
        if (fail_count == 0)
            $display("*** ALL TESTS PASSED ***");
        else
            $display("*** %0d TESTS FAILED ***", fail_count);
        $finish;
    end

    // Timeout watchdog
    initial begin
        #5_000_000;  // 5 seconds max
        $display("FAIL: Simulation timeout!");
        $finish;
    end

endmodule
