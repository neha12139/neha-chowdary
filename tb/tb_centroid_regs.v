// ============================================================
//  Testbench : tb_centroid_regs
//  Tests     : centroid_regs.v  (Step 3 of 7)
//  Simulator : Xilinx Vivado Simulator (xsim)
// ------------------------------------------------------------
//  HOW TO RUN IN VIVADO:
//    1. Add centroid_regs.v   as Design Source
//    2. Add this file         as Simulation Source
//    3. Set tb_centroid_regs  as Top (Simulation Sources)
//    4. Flow → Run Simulation → Run Behavioral Simulation
//    5. Check Tcl console - all lines should show PASS
//
//  TEST PLAN:
//    Phase 1 - Reset check
//              After rst=1, all centroids must hold default values.
//    Phase 2 - Write centroid 0
//              Write new RGB, verify read port c0 updates next cycle.
//    Phase 3 - Write centroid 3
//              Write to last centroid, verify others unchanged.
//    Phase 4 - Sequential write all 4
//              Write all centroids one by one, verify all correct.
//    Phase 5 - Write-enable gate
//              wr_en=0, send data - registers must NOT change.
// ============================================================

`timescale 1ns / 1ps

module tb_centroid_regs;

    // ── Clock and reset ──
    reg clk = 0;
    reg rst = 0;

    // ── Write interface ──
    reg        wr_en  = 0;
    reg [1:0]  wr_sel = 0;
    reg [7:0]  wr_r   = 0;
    reg [7:0]  wr_g   = 0;
    reg [7:0]  wr_b   = 0;

    // ── Read ports ──
    wire [7:0] c0_r, c0_g, c0_b;
    wire [7:0] c1_r, c1_g, c1_b;
    wire [7:0] c2_r, c2_g, c2_b;
    wire [7:0] c3_r, c3_g, c3_b;

    // ── Instantiate DUT ──
    centroid_regs uut (
        .clk   (clk),
        .rst   (rst),
        .wr_en (wr_en),
        .wr_sel(wr_sel),
        .wr_r  (wr_r),
        .wr_g  (wr_g),
        .wr_b  (wr_b),
        .c0_r(c0_r), .c0_g(c0_g), .c0_b(c0_b),
        .c1_r(c1_r), .c1_g(c1_g), .c1_b(c1_b),
        .c2_r(c2_r), .c2_g(c2_g), .c2_b(c2_b),
        .c3_r(c3_r), .c3_g(c3_g), .c3_b(c3_b)
    );

    // ── 10ns clock ──
    always #5 clk = ~clk;

    // ── Counters ──
    integer pass_count = 0;
    integer fail_count = 0;

    // ── Check task ──
    task check;
        input [7:0] got_r, got_g, got_b;
        input [7:0] exp_r, exp_g, exp_b;
        input [7:0] k;
        input [63:0] tc_num;
        begin
            if (got_r===exp_r && got_g===exp_g && got_b===exp_b) begin
                $display("TC%0d  PASS | C%0d = (%0d,%0d,%0d)",
                         tc_num, k, got_r, got_g, got_b);
                pass_count = pass_count + 1;
            end else begin
                $display("TC%0d  FAIL | C%0d got=(%0d,%0d,%0d) expected=(%0d,%0d,%0d)",
                         tc_num, k, got_r, got_g, got_b, exp_r, exp_g, exp_b);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Helper: write one centroid and wait one cycle ──
    task write_centroid;
        input [1:0]  sel;
        input [7:0]  r, g, b;
        begin
            @(negedge clk);   // drive on falling edge
            wr_en  = 1;
            wr_sel = sel;
            wr_r   = r;
            wr_g   = g;
            wr_b   = b;
            @(posedge clk);   // latch on rising edge
            #1;               // small settle time
            wr_en  = 0;
        end
    endtask

    // ── Main stimulus ──
    initial begin
        $display("============================================");
        $display(" centroid_regs Testbench - Step 3 of 7    ");
        $display("============================================");

        // ── Phase 1: Reset ──
        $display("-- Phase 1: Reset check --");
        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        // After reset: C0=FF0000, C1=00FF00, C2=0000FF, C3=FFFF00
        check(c0_r, c0_g, c0_b,  8'hFF, 8'h00, 8'h00,  0, 1);
        check(c1_r, c1_g, c1_b,  8'h00, 8'hFF, 8'h00,  1, 2);
        check(c2_r, c2_g, c2_b,  8'h00, 8'h00, 8'hFF,  2, 3);
        check(c3_r, c3_g, c3_b,  8'hFF, 8'hFF, 8'h00,  3, 4);

        // ── Phase 2: Write centroid 0 ──
        $display("-- Phase 2: Write centroid 0 --");
        write_centroid(2'd0, 8'd180, 8'd120, 8'd60);
        check(c0_r, c0_g, c0_b,  8'd180, 8'd120, 8'd60,  0, 5);
        // others must be unchanged
        check(c1_r, c1_g, c1_b,  8'h00, 8'hFF, 8'h00,  1, 6);

        // ── Phase 3: Write centroid 3 ──
        $display("-- Phase 3: Write centroid 3 --");
        write_centroid(2'd3, 8'd240, 8'd80, 8'd10);
        check(c3_r, c3_g, c3_b,  8'd240, 8'd80, 8'd10,  3, 7);
        // C0 must still hold its written value
        check(c0_r, c0_g, c0_b,  8'd180, 8'd120, 8'd60,  0, 8);

        // ── Phase 4: Write all 4 sequentially ──
        $display("-- Phase 4: Sequential write all 4 --");
        write_centroid(2'd0, 8'd10,  8'd20,  8'd30);
        write_centroid(2'd1, 8'd40,  8'd50,  8'd60);
        write_centroid(2'd2, 8'd70,  8'd80,  8'd90);
        write_centroid(2'd3, 8'd100, 8'd110, 8'd120);

        check(c0_r, c0_g, c0_b,  8'd10,  8'd20,  8'd30,   0, 9);
        check(c1_r, c1_g, c1_b,  8'd40,  8'd50,  8'd60,   1, 10);
        check(c2_r, c2_g, c2_b,  8'd70,  8'd80,  8'd90,   2, 11);
        check(c3_r, c3_g, c3_b,  8'd100, 8'd110, 8'd120,  3, 12);

        // ── Phase 5: Write-enable gate ──
        $display("-- Phase 5: wr_en=0 must not change registers --");
        @(negedge clk);
        wr_en = 0; wr_sel = 2'd0; wr_r = 8'hAA; wr_g = 8'hBB; wr_b = 8'hCC;
        @(posedge clk); #1;
        // C0 must still be 10,20,30 - NOT AA,BB,CC
        check(c0_r, c0_g, c0_b,  8'd10, 8'd20, 8'd30,  0, 13);

        // ── Summary ──
        $display("--------------------------------------------");
        $display(" Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - centroid_regs verified.");
        else
            $display(" FAILURES DETECTED - check write-enable or reset.");
        $display("============================================");

        $finish;
    end

endmodule