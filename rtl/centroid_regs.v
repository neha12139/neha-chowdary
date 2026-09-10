// ============================================================
//  Module  : centroid_regs
//  Project : K-Means Hardware Accelerator
//  Step    : 3 of 7
// ------------------------------------------------------------
//  Purpose : Stores 4 centroids, each with R, G, B (8-bit).
//            Total = 4 × 3 = 12 registers of 8 bits each.
//
//  Python equivalent (your reference model):
//      centroids = np.array([[R0,G0,B0],
//                            [R1,G1,B1],
//                            [R2,G2,B2],
//                            [R3,G3,B3]])
//
//  Two operations this module supports:
//
//  READ  - combinational, every cycle
//          All 4 centroids are always visible on output ports.
//          dist_unit_0 reads C0, dist_unit_1 reads C1, etc.
//          No clock needed for read - outputs update instantly.
//
//  WRITE - clocked, one centroid at a time
//          Accumulator (Step 4) asserts wr_en[k] + new R,G,B
//          On rising clock edge → centroid[k] updates.
//          Only one centroid written per clock (FSM controls which).
//
//  INIT  - on reset
//          Loads initial centroid values from parameters.
//          In full system these come from centroids.mem via
//          the testbench $readmemh - here we use reset defaults.
//
//  Ports:
//      clk               - system clock
//      rst               - synchronous reset (loads init values)
//      wr_en    [3:0]    - write enable, one bit per centroid
//      wr_sel   [1:0]    - which centroid to write (0-3)
//      wr_r/g/b [7:0]    - new centroid RGB from accumulator
//      c0_r/g/b [7:0]    - centroid 0 read ports → dist_unit_0
//      c1_r/g/b [7:0]    - centroid 1 read ports → dist_unit_1
//      c2_r/g/b [7:0]    - centroid 2 read ports → dist_unit_2
//      c3_r/g/b [7:0]    - centroid 3 read ports → dist_unit_3
// ============================================================

`timescale 1ns / 1ps

module centroid_regs (
    // ── Clock and reset ──
    input  wire        clk,
    input  wire        rst,       // synchronous reset

    // ── Write interface (from accumulator, Step 4) ──
    input  wire        wr_en,     // write enable (high = write this cycle)
    input  wire [1:0]  wr_sel,    // which centroid to write (0,1,2,3)
    input  wire [7:0]  wr_r,      // new R value
    input  wire [7:0]  wr_g,      // new G value
    input  wire [7:0]  wr_b,      // new B value

    // ── Read ports - centroid 0 → dist_unit_0 ──
    output wire [7:0]  c0_r,
    output wire [7:0]  c0_g,
    output wire [7:0]  c0_b,

    // ── Read ports - centroid 1 → dist_unit_1 ──
    output wire [7:0]  c1_r,
    output wire [7:0]  c1_g,
    output wire [7:0]  c1_b,

    // ── Read ports - centroid 2 → dist_unit_2 ──
    output wire [7:0]  c2_r,
    output wire [7:0]  c2_g,
    output wire [7:0]  c2_b,

    // ── Read ports - centroid 3 → dist_unit_3 ──
    output wire [7:0]  c3_r,
    output wire [7:0]  c3_g,
    output wire [7:0]  c3_b
);

    // ----------------------------------------------------------
    //  Internal storage - 4 centroids × 3 channels × 8 bits
    //  Organised as two arrays: cent_r[k], cent_g[k], cent_b[k]
    //  Index k = 0,1,2,3 maps to centroid number
    // ----------------------------------------------------------
    reg [7:0] cent_r [0:3];
    reg [7:0] cent_g [0:3];
    reg [7:0] cent_b [0:3];

    // ----------------------------------------------------------
    //  Clocked write + synchronous reset
    //
    //  On rst=1  : load default initial centroids
    //              These match the first 4 lines of centroids.mem
    //              (your Python export_mem.py chooses these randomly
    //               from the image - here we use fixed defaults for
    //               simulation; testbench overrides via $readmemh)
    //
    //  On wr_en=1: write new R,G,B into centroid[wr_sel]
    //
    //  Python equivalent:
    //      centroids[wr_sel] = [wr_r, wr_g, wr_b]
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            // Default initial centroids (placeholders)
            // Testbench will override these with real image centroids
            cent_r[0] <= 8'hFF; cent_g[0] <= 8'h00; cent_b[0] <= 8'h00; // red-ish
            cent_r[1] <= 8'h00; cent_g[1] <= 8'hFF; cent_b[1] <= 8'h00; // green-ish
            cent_r[2] <= 8'h00; cent_g[2] <= 8'h00; cent_b[2] <= 8'hFF; // blue-ish
            cent_r[3] <= 8'hFF; cent_g[3] <= 8'hFF; cent_b[3] <= 8'h00; // yellow-ish
        end
        else if (wr_en) begin
            // Write new centroid values from accumulator
            cent_r[wr_sel] <= wr_r;
            cent_g[wr_sel] <= wr_g;
            cent_b[wr_sel] <= wr_b;
        end
    end

    // ----------------------------------------------------------
    //  Combinational read - all 4 centroids always visible
    //  dist_unit instances read these every cycle with no latency
    //
    //  Python equivalent:
    //      c = centroids[k]   →   c[0]=R, c[1]=G, c[2]=B
    // ----------------------------------------------------------
    assign c0_r = cent_r[0]; assign c0_g = cent_g[0]; assign c0_b = cent_b[0];
    assign c1_r = cent_r[1]; assign c1_g = cent_g[1]; assign c1_b = cent_b[1];
    assign c2_r = cent_r[2]; assign c2_g = cent_g[2]; assign c2_b = cent_b[2];
    assign c3_r = cent_r[3]; assign c3_g = cent_g[3]; assign c3_b = cent_b[3];

endmodule