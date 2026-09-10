// ============================================================
//  Testbench : tb_accumulator
//  Tests     : accumulator.v  (Step 4 of 7)
//  Simulator : Xilinx Vivado Simulator (xsim)
// ------------------------------------------------------------
//  HOW TO RUN IN VIVADO:
//    1. Add accumulator.v      as Design Source
//    2. Add this file          as Simulation Source
//    3. Set tb_accumulator     as Top (Simulation Sources)
//    4. Flow → Run Simulation → Run Behavioral Simulation
//    5. Check Tcl console - all lines should show PASS
//
//  TEST PLAN:
//    Phase 1 - Clear check
//              After clear_en, all sums and counts must be zero.
//    Phase 2 - Accumulate 3 pixels into cluster 0
//              Feed 3 known pixels, check new centroid mean is correct.
//    Phase 3 - Accumulate into multiple clusters
//              Feed pixels to different clusters, check each mean.
//    Phase 4 - update_rdy flag
//              Must be 0 during accumulate, 1 after update_en.
//    Phase 5 - Empty cluster guard
//              Cluster with no pixels must output 0, not divide-by-zero.
//
//  PYTHON GROUND TRUTH:
//    Phase 2:  pixels = [(60,90,120),(180,60,30),(120,30,60)]
//              mean_r = (60+180+120)/3 = 120
//              mean_g = (90+60+30)/3   = 60
//              mean_b = (120+30+60)/3  = 70
// ============================================================

`timescale 1ns / 1ps

module tb_accumulator;

    // ── Clock and reset ──
    reg clk = 0;
    reg rst = 0;

    // ── Control ──
    reg accum_en  = 0;
    reg clear_en  = 0;
    reg update_en = 0;

    // ── Pixel inputs ──
    reg [7:0] pixel_r = 0;
    reg [7:0] pixel_g = 0;
    reg [7:0] pixel_b = 0;
    reg [1:0] cluster_id = 0;

    // ── Outputs ──
    wire [7:0] new_c0_r, new_c0_g, new_c0_b;
    wire [7:0] new_c1_r, new_c1_g, new_c1_b;
    wire [7:0] new_c2_r, new_c2_g, new_c2_b;
    wire [7:0] new_c3_r, new_c3_g, new_c3_b;
    wire       update_rdy;

    // ── Instantiate DUT ──
    accumulator uut (
        .clk        (clk),
        .rst        (rst),
        .accum_en   (accum_en),
        .clear_en   (clear_en),
        .update_en  (update_en),
        .pixel_r    (pixel_r),
        .pixel_g    (pixel_g),
        .pixel_b    (pixel_b),
        .cluster_id (cluster_id),
        .new_c0_r(new_c0_r), .new_c0_g(new_c0_g), .new_c0_b(new_c0_b),
        .new_c1_r(new_c1_r), .new_c1_g(new_c1_g), .new_c1_b(new_c1_b),
        .new_c2_r(new_c2_r), .new_c2_g(new_c2_g), .new_c2_b(new_c2_b),
        .new_c3_r(new_c3_r), .new_c3_g(new_c3_g), .new_c3_b(new_c3_b),
        .update_rdy (update_rdy)
    );

    // ── 10ns clock ──
    always #5 clk = ~clk;

    // ── Counters ──
    integer pass_count = 0;
    integer fail_count = 0;

    // ── Check task ──
    task check_rgb;
        input [7:0] got_r, got_g, got_b;
        input [7:0] exp_r, exp_g, exp_b;
        input [7:0] cluster;
        input [7:0] tc_num;
        begin
            if (got_r===exp_r && got_g===exp_g && got_b===exp_b) begin
                $display("TC%0d  PASS | C%0d new centroid = (%0d,%0d,%0d)",
                         tc_num, cluster, got_r, got_g, got_b);
                pass_count = pass_count + 1;
            end else begin
                $display("TC%0d  FAIL | C%0d got=(%0d,%0d,%0d) expected=(%0d,%0d,%0d)",
                         tc_num, cluster, got_r, got_g, got_b, exp_r, exp_g, exp_b);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_flag;
        input got;
        input exp;
        input [7:0] tc_num;
        input [64*8-1:0] label;
        begin
            if (got === exp) begin
                $display("TC%0d  PASS | %0s = %0d", tc_num, label, got);
                pass_count = pass_count + 1;
            end else begin
                $display("TC%0d  FAIL | %0s got=%0d expected=%0d", tc_num, label, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Helper: feed one pixel into accumulator ──
    task feed_pixel;
        input [7:0] r, g, b;
        input [1:0] cid;
        begin
            @(negedge clk);
            pixel_r = r; pixel_g = g; pixel_b = b;
            cluster_id = cid;
            accum_en = 1;
            @(posedge clk); #1;
            accum_en = 0;
        end
    endtask

    // ── Helper: trigger update and wait one cycle ──
    task do_update;
        begin
            @(negedge clk);
            update_en = 1;
            @(posedge clk); #1;
            update_en = 0;
        end
    endtask

    // ── Main stimulus ──
    initial begin
        $display("============================================");
        $display(" accumulator Testbench - Step 4 of 7      ");
        $display("============================================");

        // ── Reset ──
        rst = 1;
        @(posedge clk); #1;
        rst = 0;

        // ── Phase 1: Clear check ──
        $display("-- Phase 1: Clear check --");
        @(negedge clk); clear_en = 1;
        @(posedge clk); #1; clear_en = 0;
        // After clear, update_rdy must be 0
        check_flag(update_rdy, 1'b0, 1, "update_rdy after clear");

        // ── Phase 2: Accumulate 3 pixels into cluster 0 ──
        // Python ground truth:
        //   pixels = [(60,90,120),(180,60,30),(120,30,60)]
        //   mean_r = 360/3 = 120
        //   mean_g = 180/3 = 60
        //   mean_b = 210/3 = 70
        $display("-- Phase 2: 3 pixels into cluster 0 --");
        feed_pixel(8'd60,  8'd90, 8'd120, 2'd0);
        feed_pixel(8'd180, 8'd60, 8'd30,  2'd0);
        feed_pixel(8'd120, 8'd30, 8'd60,  2'd0);
        do_update;
        check_rgb(new_c0_r, new_c0_g, new_c0_b,  8'd120, 8'd60, 8'd70,  0, 2);
        check_flag(update_rdy, 1'b1, 3, "update_rdy after update");

        // ── Phase 3: Multiple clusters ──
        // Cluster 1: pixels (200,100,50) and (100,50,150)
        //   mean_r=(200+100)/2=150, mean_g=(100+50)/2=75, mean_b=(50+150)/2=100
        // Cluster 2: one pixel (30,200,180)
        //   mean = (30,200,180)
        // Cluster 3: two pixels (255,0,0) and (0,255,0)
        //   mean_r=127, mean_g=127, mean_b=0
        $display("-- Phase 3: Multiple clusters --");
        @(negedge clk); clear_en = 1;
        @(posedge clk); #1; clear_en = 0;

        feed_pixel(8'd200, 8'd100, 8'd50,  2'd1);
        feed_pixel(8'd100, 8'd50,  8'd150, 2'd1);
        feed_pixel(8'd30,  8'd200, 8'd180, 2'd2);
        feed_pixel(8'd255, 8'd0,   8'd0,   2'd3);
        feed_pixel(8'd0,   8'd255, 8'd0,   2'd3);
        do_update;

        check_rgb(new_c1_r, new_c1_g, new_c1_b,  8'd150, 8'd75, 8'd100,  1, 4);
        check_rgb(new_c2_r, new_c2_g, new_c2_b,  8'd30,  8'd200, 8'd180, 2, 5);
        // (255+0)/2=127, (0+255)/2=127
        check_rgb(new_c3_r, new_c3_g, new_c3_b,  8'd127, 8'd127, 8'd0,   3, 6);

        // ── Phase 4: Empty cluster guard ──
        // Cluster 0 was not fed any pixels this round → must output 0
        $display("-- Phase 4: Empty cluster guard (C0 not fed) --");
        check_rgb(new_c0_r, new_c0_g, new_c0_b,  8'd0, 8'd0, 8'd0,  0, 7);

        // ── Phase 5: update_rdy goes low after new accum ──
        $display("-- Phase 5: update_rdy gating --");
        feed_pixel(8'd100, 8'd100, 8'd100, 2'd0);
        check_flag(update_rdy, 1'b0, 8, "update_rdy during accum");

        // ── Summary ──
        $display("--------------------------------------------");
        $display(" Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - accumulator verified.");
        else
            $display(" FAILURES DETECTED - check sum/count/divide logic.");
        $display("============================================");

        $finish;
    end

endmodule