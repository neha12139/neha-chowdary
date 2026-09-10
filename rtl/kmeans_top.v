// ============================================================
//  Module  : kmeans_top
//  Project : K-Means Hardware Accelerator
//  Step    : 6b of 7
// ------------------------------------------------------------
//  Purpose : Top-level module that instantiates and connects
//            all 5 sub-modules into a complete K-Means
//            hardware accelerator.
//
//  Full data flow:
//
//  pixels.mem
//      ↓ $readmemh
//  [pixel_mem] ──rd_en,addr──→ pixel_r/g/b
//      ↓ pixel_r/g/b (broadcast to all 4 dist_units)
//  [dist_unit_0] ←── C0_r/g/b from centroid_regs
//  [dist_unit_1] ←── C1_r/g/b from centroid_regs
//  [dist_unit_2] ←── C2_r/g/b from centroid_regs
//  [dist_unit_3] ←── C3_r/g/b from centroid_regs
//      ↓ dist0, dist1, dist2, dist3
//  [min_finder_k4] → cluster_id[1:0]
//      ↓ cluster_id
//  [accumulator] ←── pixel_r/g/b, accum_en, update_en, clear_en
//      ↓ new_c0..c3 R/G/B, update_rdy
//  [centroid_regs] ←── wr_en, wr_sel, wr_r/g/b from mux below
//      ↓ C0..C3 R/G/B (feedback to dist_units above)
//
//  [fsm_control] drives all enable/select signals above
//      ↑ start (from testbench)
//      ↓ done  (to testbench)
//
//  Write-back mux:
//      During UPDATE, fsm_control asserts wr_sel=0,1,2,3
//      sequentially. A mux selects the matching new centroid
//      from the accumulator outputs and routes it to
//      centroid_regs write ports.
//
//  Output:
//      cluster_id[1:0] - valid when pixel_valid=1
//      done            - all iterations complete
// ============================================================

`timescale 1ns / 1ps

module kmeans_top (
    input  wire        clk,
    input  wire        rst,
    input  wire        start,        // begin clustering

    output wire [1:0]  cluster_id,   // current pixel's cluster
    output wire        pixel_valid,  // cluster_id is valid this cycle
    output wire        done          // all iterations complete
);

    // ----------------------------------------------------------
    //  Internal wires - FSM control signals
    // ----------------------------------------------------------
    wire [9:0] pixel_addr;
    wire       rd_en;
    wire       accum_en;
    wire       clear_en;
    wire       update_en;
    wire       wr_en;
    wire [1:0] wr_sel;
    wire       update_rdy;
    wire [2:0] state_out;   // debug only

    // ----------------------------------------------------------
    //  Internal wires - pixel data
    // ----------------------------------------------------------
    wire [7:0] pixel_r, pixel_g, pixel_b;

    // ----------------------------------------------------------
    //  Internal wires - centroid read ports
    // ----------------------------------------------------------
    wire [7:0] c0_r, c0_g, c0_b;
    wire [7:0] c1_r, c1_g, c1_b;
    wire [7:0] c2_r, c2_g, c2_b;
    wire [7:0] c3_r, c3_g, c3_b;

    // ----------------------------------------------------------
    //  Internal wires - distance outputs
    // ----------------------------------------------------------
    wire [17:0] dist0, dist1, dist2, dist3;

    // ----------------------------------------------------------
    //  Internal wires - accumulator new centroid outputs
    // ----------------------------------------------------------
    wire [7:0] new_c0_r, new_c0_g, new_c0_b;
    wire [7:0] new_c1_r, new_c1_g, new_c1_b;
    wire [7:0] new_c2_r, new_c2_g, new_c2_b;
    wire [7:0] new_c3_r, new_c3_g, new_c3_b;

    // ----------------------------------------------------------
    //  Write-back mux
    //  Routes the correct new centroid to centroid_regs
    //  based on wr_sel from FSM
    // ----------------------------------------------------------
    reg [7:0] wr_r, wr_g, wr_b;

    always @(*) begin
        case (wr_sel)
            2'd0: begin wr_r = new_c0_r; wr_g = new_c0_g; wr_b = new_c0_b; end
            2'd1: begin wr_r = new_c1_r; wr_g = new_c1_g; wr_b = new_c1_b; end
            2'd2: begin wr_r = new_c2_r; wr_g = new_c2_g; wr_b = new_c2_b; end
            2'd3: begin wr_r = new_c3_r; wr_g = new_c3_g; wr_b = new_c3_b; end
        endcase
    end

    // ----------------------------------------------------------
    //  Module instantiations
    // ----------------------------------------------------------

    // ── 1. FSM Control ──
    fsm_control u_fsm (
        .clk        (clk),
        .rst        (rst),
        .start      (start),
        .update_rdy (update_rdy),
        .pixel_addr (pixel_addr),
        .rd_en      (rd_en),
        .accum_en   (accum_en),
        .clear_en   (clear_en),
        .update_en  (update_en),
        .wr_en      (wr_en),
        .wr_sel     (wr_sel),
        .done       (done),
        .state_out  (state_out)
    );

    // ── 2. Pixel Memory ──
    pixel_mem u_pixel_mem (
        .clk         (clk),
        .rd_en       (rd_en),
        .addr        (pixel_addr),
        .pixel_r     (pixel_r),
        .pixel_g     (pixel_g),
        .pixel_b     (pixel_b),
        .pixel_valid (pixel_valid)
    );

    // ── 3. Centroid Register File ──
    centroid_regs u_cent_regs (
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

    // ── 4a. Distance Unit - Centroid 0 ──
    dist_unit u_dist0 (
        .pixel_r (pixel_r), .pixel_g (pixel_g), .pixel_b (pixel_b),
        .cent_r  (c0_r),    .cent_g  (c0_g),    .cent_b  (c0_b),
        .dist_sq (dist0)
    );

    // ── 4b. Distance Unit - Centroid 1 ──
    dist_unit u_dist1 (
        .pixel_r (pixel_r), .pixel_g (pixel_g), .pixel_b (pixel_b),
        .cent_r  (c1_r),    .cent_g  (c1_g),    .cent_b  (c1_b),
        .dist_sq (dist1)
    );

    // ── 4c. Distance Unit - Centroid 2 ──
    dist_unit u_dist2 (
        .pixel_r (pixel_r), .pixel_g (pixel_g), .pixel_b (pixel_b),
        .cent_r  (c2_r),    .cent_g  (c2_g),    .cent_b  (c2_b),
        .dist_sq (dist2)
    );

    // ── 4d. Distance Unit - Centroid 3 ──
    dist_unit u_dist3 (
        .pixel_r (pixel_r), .pixel_g (pixel_g), .pixel_b (pixel_b),
        .cent_r  (c3_r),    .cent_g  (c3_g),    .cent_b  (c3_b),
        .dist_sq (dist3)
    );

    // ── 5. Min Finder - Tournament Tree ──
    min_finder_k4 u_min_finder (
        .dist0      (dist0),
        .dist1      (dist1),
        .dist2      (dist2),
        .dist3      (dist3),
        .cluster_id (cluster_id)
    );

    // ── 6. Accumulator ──
    accumulator u_accum (
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

endmodule