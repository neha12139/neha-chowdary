// ============================================================
//  Testbench : tb_min_finder_k4
//  Tests     : min_finder_k4.v  (Step 2 of 7)
//  Simulator : Xilinx Vivado Simulator (xsim)
// ------------------------------------------------------------
//  HOW TO RUN IN VIVADO:
//    1. Add min_finder_k4.v   as Design Source
//    2. Add this file         as Simulation Source
//    3. Set tb_min_finder_k4  as Top (Simulation Sources)
//    4. Flow → Run Simulation → Run Behavioral Simulation
//    5. Check Tcl console - all lines should show PASS
//
//  TEST CASES:
//    TC1 - D0 is clearly smallest         → expect cluster 0
//    TC2 - D1 is clearly smallest         → expect cluster 1
//    TC3 - D2 is clearly smallest         → expect cluster 2
//    TC4 - D3 is clearly smallest         → expect cluster 3
//    TC5 - Tie between D0 and D1          → expect cluster 0 (lower index wins)
//    TC6 - Realistic distances from image → cross-check with Python
// ============================================================

`timescale 1ns / 1ps

module tb_min_finder_k4;

    // ── DUT inputs ──
    reg [17:0] dist0, dist1, dist2, dist3;

    // ── DUT output ──
    wire [1:0] cluster_id;

    // ── Instantiate DUT ──
    min_finder_k4 uut (
        .dist0      (dist0),
        .dist1      (dist1),
        .dist2      (dist2),
        .dist3      (dist3),
        .cluster_id (cluster_id)
    );

    // ── Counters ──
    integer pass_count = 0;
    integer fail_count = 0;

    // ── Task: apply vector, wait, check, report ──
    task apply_and_check;
        input [17:0] d0, d1, d2, d3;
        input [1:0]  expected_id;
        input [7:0]  tc_num;
        begin
            dist0 = d0; dist1 = d1; dist2 = d2; dist3 = d3;
            #10;

            if (cluster_id === expected_id) begin
                $display("TC%0d  PASS | D=(%0d,%0d,%0d,%0d) | cluster_id=%0d",
                         tc_num, d0, d1, d2, d3, cluster_id);
                pass_count = pass_count + 1;
            end else begin
                $display("TC%0d  FAIL | D=(%0d,%0d,%0d,%0d) | got=%0d expected=%0d",
                         tc_num, d0, d1, d2, d3, cluster_id, expected_id);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // ── Stimulus ──
    initial begin
        $display("============================================");
        $display(" min_finder_k4 Testbench - Step 2 of 7    ");
        $display("============================================");

        // TC1 - D0 is smallest → cluster 0
        // Python: np.argmin([100, 500, 800, 1200]) = 0
        apply_and_check(18'd100,  18'd500,  18'd800,  18'd1200, 2'd0, 1);

        // TC2 - D1 is smallest → cluster 1
        // Python: np.argmin([900, 200, 750, 1100]) = 1
        apply_and_check(18'd900,  18'd200,  18'd750,  18'd1100, 2'd1, 2);

        // TC3 - D2 is smallest → cluster 2
        // Python: np.argmin([5000, 3000, 400, 2200]) = 2
        apply_and_check(18'd5000, 18'd3000, 18'd400,  18'd2200, 2'd2, 3);

        // TC4 - D3 is smallest → cluster 3
        // Python: np.argmin([8000, 6000, 4000, 300]) = 3
        apply_and_check(18'd8000, 18'd6000, 18'd4000, 18'd300,  2'd3, 4);

        // TC5 - Tie between D0 and D1 → lower index wins → cluster 0
        // Python: np.argmin([1200, 1200, 5000, 9000]) = 0
        apply_and_check(18'd1200, 18'd1200, 18'd5000, 18'd9000, 2'd0, 5);

        // TC6 - Realistic distances from a warm pixel vs 4 centroids
        // Pixel  = (180, 120, 60)
        // C0=(200,100,80)  → dist = 400+400+400   = 1200
        // C1=(50,  50, 50) → dist = 16900+4900+100= 21900
        // C2=(100,200,200) → dist = 6400+6400+19600= 32400
        // C3=(240,230,220) → dist = 3600+12100+25600= 41300
        // Python: np.argmin([1200, 21900, 32400, 41300]) = 0
        apply_and_check(18'd1200, 18'd21900, 18'd32400, 18'd41300, 2'd0, 6);

        // ── Summary ──
        $display("--------------------------------------------");
        $display(" Results: %0d PASSED,  %0d FAILED", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED - min_finder_k4 verified.");
        else
            $display(" FAILURES DETECTED - check comparator logic.");
        $display("============================================");

        $finish;
    end

endmodule