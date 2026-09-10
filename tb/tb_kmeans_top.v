// ============================================================
//  Testbench : tb_kmeans_top  (FIXED v2)
//  Tests     : kmeans_top.v - Full K-Means Hardware Accelerator
//  Step      : 7 of 7  (FINAL)
//  Simulator : Xilinx Vivado Simulator (xsim)
// ------------------------------------------------------------
//  FIXES FROM v1:
//    - Robust reset sequence (hold rst longer)
//    - start pulse held for 4 full clock cycles
//    - Monitor uses always @(posedge clk) - no fork/join_none
//    - Timeout prints FSM internal state for debugging
// ============================================================

`timescale 1ns / 1ps

module tb_kmeans_top;

    // ── Clock and control ──
    reg clk   = 0;
    reg rst   = 1;
    reg start = 0;

    // ── DUT outputs ──
    wire [1:0] cluster_id;
    wire       pixel_valid;
    wire       done;

    // ── 10ns clock (100 MHz) ──
    always #5 clk = ~clk;

    // ── Instantiate top-level DUT ──
    kmeans_top uut (
        .clk         (clk),
        .rst         (rst),
        .start       (start),
        .cluster_id  (cluster_id),
        .pixel_valid (pixel_valid),
        .done        (done)
    );

    // ── Tracking variables ──
    integer pixel_count  = 0;
    integer iter_num     = 0;
    integer clust_cnt_0  = 0;
    integer clust_cnt_1  = 0;
    integer clust_cnt_2  = 0;
    integer clust_cnt_3  = 0;
    integer total_pixels = 0;
    integer sim_done     = 0;

    // ── Load initial centroids from centroids.mem ──
    initial begin
        #1;
        begin : load_centroids
            reg [23:0] cent_data [0:3];
            $readmemh("centroids.mem", cent_data);

            uut.u_cent_regs.cent_r[0] = cent_data[0][23:16];
            uut.u_cent_regs.cent_g[0] = cent_data[0][15:8];
            uut.u_cent_regs.cent_b[0] = cent_data[0][7:0];

            uut.u_cent_regs.cent_r[1] = cent_data[1][23:16];
            uut.u_cent_regs.cent_g[1] = cent_data[1][15:8];
            uut.u_cent_regs.cent_b[1] = cent_data[1][7:0];

            uut.u_cent_regs.cent_r[2] = cent_data[2][23:16];
            uut.u_cent_regs.cent_g[2] = cent_data[2][15:8];
            uut.u_cent_regs.cent_b[2] = cent_data[2][7:0];

            uut.u_cent_regs.cent_r[3] = cent_data[3][23:16];
            uut.u_cent_regs.cent_g[3] = cent_data[3][15:8];
            uut.u_cent_regs.cent_b[3] = cent_data[3][7:0];

            $display("============================================");
            $display(" K-Means Hardware Accelerator - Step 7/7  ");
            $display("============================================");
            $display("Initial centroids loaded:");
            $display("  C0: R=%0d G=%0d B=%0d",
                cent_data[0][23:16],cent_data[0][15:8],cent_data[0][7:0]);
            $display("  C1: R=%0d G=%0d B=%0d",
                cent_data[1][23:16],cent_data[1][15:8],cent_data[1][7:0]);
            $display("  C2: R=%0d G=%0d B=%0d",
                cent_data[2][23:16],cent_data[2][15:8],cent_data[2][7:0]);
            $display("  C3: R=%0d G=%0d B=%0d",
                cent_data[3][23:16],cent_data[3][15:8],cent_data[3][7:0]);
            $display("--------------------------------------------");
        end
    end

    // ── Reset and start sequence ──
    initial begin
        // Hold reset for 10 clock cycles
        rst   = 1;
        start = 0;
        repeat(10) @(posedge clk);
        #2;
        rst = 0;

        // Wait 4 more cycles after reset release
        repeat(4) @(posedge clk);

        // Hold start HIGH for 4 clock cycles (robust pulse)
        $display("Asserting start...");
        repeat(4) begin
            @(negedge clk);
            start = 1;
        end
        @(negedge clk);
        start = 0;

        $display("Accelerator started. Waiting for pixels...");
        $display("--------------------------------------------");

        // Wait for done
        wait(done === 1'b1 || sim_done === 1);

        if (done === 1'b1) begin
            repeat(3) @(posedge clk);
            $display("============================================");
            $display(" DONE - all iterations complete            ");
            $display("============================================");
            $display("Total pixels processed: %0d", total_pixels);
            $display("");
            $display("Final centroids:");
            $display("  C0: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[0],
                uut.u_cent_regs.cent_g[0],
                uut.u_cent_regs.cent_b[0]);
            $display("  C1: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[1],
                uut.u_cent_regs.cent_g[1],
                uut.u_cent_regs.cent_b[1]);
            $display("  C2: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[2],
                uut.u_cent_regs.cent_g[2],
                uut.u_cent_regs.cent_b[2]);
            $display("  C3: R=%0d G=%0d B=%0d",
                uut.u_cent_regs.cent_r[3],
                uut.u_cent_regs.cent_g[3],
                uut.u_cent_regs.cent_b[3]);
            $display("============================================");
            $display(" Compare with Python final centroids       ");
            $display("============================================");
        end

        $finish;
    end

    // ── Pixel monitor - simple always block ──
    always @(posedge clk) begin
        if (pixel_valid && !done) begin
            if (pixel_count < 5)
                $display("  iter=%0d pixel=%0d cluster=%0d",
                         iter_num, pixel_count, cluster_id);
            if (pixel_count == 5)
                $display("  iter=%0d ... (remaining omitted)", iter_num);

            case (cluster_id)
                2'd0: clust_cnt_0 = clust_cnt_0 + 1;
                2'd1: clust_cnt_1 = clust_cnt_1 + 1;
                2'd2: clust_cnt_2 = clust_cnt_2 + 1;
                2'd3: clust_cnt_3 = clust_cnt_3 + 1;
            endcase

            pixel_count  = pixel_count  + 1;
            total_pixels = total_pixels + 1;

            if (pixel_count == 1024) begin
                $display("--------------------------------------------");
                $display("Iter %0d done | C0:%0d C1:%0d C2:%0d C3:%0d px",
                    iter_num,
                    clust_cnt_0, clust_cnt_1,
                    clust_cnt_2, clust_cnt_3);
                $display("--------------------------------------------");
                pixel_count = 0;
                iter_num    = iter_num + 1;
                clust_cnt_0 = 0; clust_cnt_1 = 0;
                clust_cnt_2 = 0; clust_cnt_3 = 0;
            end
        end
    end

    // ── Timeout watchdog ──
    initial begin
        #300_000_000;
        $display("TIMEOUT - done never received.");
        $display("FSM state   : %0d", uut.u_fsm.state);
        $display("pixel_addr  : %0d", uut.u_fsm.pixel_addr);
        $display("iter_count  : %0d", uut.u_fsm.iter_count);
        $display("update_rdy  : %0d", uut.update_rdy);
        $display("accum_en    : %0d", uut.accum_en);
        $display("pixel_valid : %0d", pixel_valid);
        sim_done = 1;
    end

endmodule