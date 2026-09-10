// ============================================================
//  Testbench : tb_pixel_mem
//  Tests     : pixel_mem.v  (Step 5 of 7)
//  Simulator : Xilinx Vivado Simulator (xsim)
// ------------------------------------------------------------
//  HOW TO RUN IN VIVADO:
//    1. Add pixel_mem.v      as Design Source
//    2. Add this file        as Simulation Source
//    3. Set tb_pixel_mem     as Top (Simulation Sources)
//    4. Flow → Run Simulation → Run Behavioral Simulation
//    5. Check Tcl console - all lines should show PASS
//
//  NOTE ON pixels.mem:
//    This testbench uses $readmemh to load test_pixels.mem
//    which is written inline by the $writememh initial block
//    below - so NO external file needed for this unit test.
//    In the full system (Step 7), the real pixels.mem from
//    your Python export_mem.py will be used instead.
//
//  TEST PLAN:
//    Phase 1 - Read address 0      → first pixel correct
//    Phase 2 - Read address 5      → mid pixel correct
//    Phase 3 - Sequential read     → addresses 0,1,2 in order
//    Phase 4 - pixel_valid gating  → low when rd_en=0
//    Phase 5 - Address 1023        → last pixel correct
// ============================================================

`timescale 1ns / 1ps

module tb_pixel_mem;

    // ── Clock ──
    reg clk = 0;
    always #5 clk = ~clk;

    // ── DUT ports ──
    reg        rd_en = 0;
    reg  [9:0] addr  = 0;
    wire [7:0] pixel_r, pixel_g, pixel_b;
    wire       pixel_valid;

    // ── Instantiate DUT ──
    pixel_mem uut (
        .clk         (clk),
        .rd_en       (rd_en),
        .addr        (addr),
        .pixel_r     (pixel_r),
        .pixel_g     (pixel_g),
        .pixel_b     (pixel_b),
        .pixel_valid (pixel_valid)
    );

    // ── Counters ──
    integer pass_count = 0;
    integer fail_count = 0;

    // ── Check task ──
    task check_pixel;
        input [7:0] exp_r, exp_g, exp_b;
        input        exp_valid;
        input [9:0]  chk_addr;
        input [7:0]  tc_num;
        begin
            if (pixel_r===exp_r && pixel_g===exp_g &&
                pixel_b===exp_b && pixel_valid===exp_valid) begin
                $display("TC%0d  PASS | addr=%0d pixel=(%0d,%0d,%0d) valid=%0d",
                         tc_num, chk_addr, pixel_r, pixel_g, pixel_b, pixel_valid);
                pass_count = pass_count + 1;
            end else begin
                $display("TC%0d  FAIL | addr=%0d got=(%0d,%0d,%0d,v=%0d) exp=(%0d,%0d,%0d,v=%0d)",
                         tc_num, chk_addr,
                         pixel_r, pixel_g, pixel_b, pixel_valid,
                         exp_r,   exp_g,   exp_b,   exp_valid);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Helper: read one address, wait one cycle for valid ──
    task read_addr;
        input [9:0] a;
        begin
            @(negedge clk);
            addr  = a;
            rd_en = 1;
            @(posedge clk); #1;   // latch happens here
            rd_en = 0;
        end
    endtask

    // ── Pre-load known test data directly into DUT memory ──
    // This bypasses the need for an external pixels.mem file
    // for unit testing. The full system uses the real file.
    initial begin
        // Wait for elaboration to complete
        #1;
        // Manually seed known pixel values into uut.mem
        // Pixel 0 : R=255, G=0,   B=0    → warm red
        uut.mem[0]    = 24'hFF0000;
        // Pixel 1 : R=0,   G=255, B=0    → green
        uut.mem[1]    = 24'h00FF00;
        // Pixel 2 : R=0,   G=0,   B=255  → blue
        uut.mem[2]    = 24'h0000FF;
        // Pixel 5 : R=180, G=120, B=60   → warm brownish
        uut.mem[5]    = 24'hB4783C;
        // Pixel 1023: R=64, G=128, B=192 → last pixel
        uut.mem[1023] = 24'h4080C0;
    end

    // ── Main stimulus ──
    initial begin
        $display("============================================");
        $display(" pixel_mem Testbench - Step 5 of 7        ");
        $display("============================================");

        // let memory seed settle
        #2;

        // ── Phase 1: Read address 0 ──
        $display("-- Phase 1: Read address 0 --");
        read_addr(10'd0);
        check_pixel(8'hFF, 8'h00, 8'h00, 1'b1, 10'd0, 1);

        // ── Phase 2: Read address 5 ──
        $display("-- Phase 2: Read address 5 --");
        read_addr(10'd5);
        check_pixel(8'hB4, 8'h78, 8'h3C, 1'b1, 10'd5, 2);

        // ── Phase 3: Sequential read 0→1→2 ──
        $display("-- Phase 3: Sequential read addresses 0,1,2 --");
        read_addr(10'd0);
        check_pixel(8'hFF, 8'h00, 8'h00, 1'b1, 10'd0, 3);

        read_addr(10'd1);
        check_pixel(8'h00, 8'hFF, 8'h00, 1'b1, 10'd1, 4);

        read_addr(10'd2);
        check_pixel(8'h00, 8'h00, 8'hFF, 1'b1, 10'd2, 5);

        // ── Phase 4: pixel_valid low when rd_en=0 ──
        $display("-- Phase 4: pixel_valid gating --");
        @(negedge clk);
        rd_en = 0; addr = 10'd0;
        @(posedge clk); #1;
        if (pixel_valid === 1'b0) begin
            $display("TC6  PASS | pixel_valid=0 when rd_en=0");
            pass_count = pass_count + 1;
        end else begin
            $display("TC6  FAIL | pixel_valid should be 0 when rd_en=0, got=%0d", pixel_valid);
            fail_count = fail_count + 1;
        end

        // ── Phase 5: Last pixel (address 1023) ──
        $display("-- Phase 5: Last pixel address 1023 --");
        read_addr(10'd1023);
        check_pixel(8'h40, 8'h80, 8'hC0, 1'b1, 10'd1023, 7);

        // ── Summary ──
        $display("--------------------------------------------");
        $display(" Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - pixel_mem verified.");
        else
            $display(" FAILURES DETECTED - check mem load or output logic.");
        $display("============================================");

        $finish;
    end

endmodule