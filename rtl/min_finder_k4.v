// ============================================================
//  Module  : min_finder_k4
//  Project : K-Means Hardware Accelerator
//  Step    : 2 of 7
// ------------------------------------------------------------
//  Purpose : Takes 4 squared distances (one per centroid) and
//            returns the index of the smallest - the winning
//            cluster ID for the current pixel.
//
//  Python equivalent (your reference model):
//      cluster_id = np.argmin([d0, d1, d2, d3])
//
//  Hardware approach - 2-level tournament tree:
//
//      D0 ──┐
//           ├─ Level-1 Compare A → min_A, id_A
//      D1 ──┘
//                                              ↘
//                                               Level-2 Final → cluster_id[1:0]
//                                              ↗
//      D2 ──┐
//           ├─ Level-1 Compare B → min_B, id_B
//      D3 ──┘
//
//  Why a tree instead of a chain?
//      A chain (compare D0 vs D1, then winner vs D2, then vs D3)
//      has 3 comparators in series - longer critical path.
//      A tree does Level-1 in PARALLEL, then one final compare.
//      This is the GPU-parallel principle in hardware.
//
//  This module is PURELY COMBINATIONAL.
//  All 4 distances arrive simultaneously, winner out same cycle.
//
//  Bit-width contract (locked by dist_unit Step 1):
//      dist inputs : [17:0]   (max 195075, fits in 18 bits)
//      cluster_id  : [1:0]    (encodes 0,1,2,3 for K=4)
//
//  Tie-breaking:
//      Lower index wins on equal distance.
//      (D0 beats D1 beats D2 beats D3 on tie)
//      This matches Python's np.argmin() behaviour - first minimum wins.
//
//  Ports:
//      dist0..dist3  [17:0]  - squared distances from 4 dist_units
//      cluster_id    [1:0]   - index of the closest centroid
// ============================================================

`timescale 1ns / 1ps

module min_finder_k4 (
    // ── 4 distance inputs (from 4 parallel dist_unit instances) ──
    input  wire [17:0] dist0,   // distance to centroid 0
    input  wire [17:0] dist1,   // distance to centroid 1
    input  wire [17:0] dist2,   // distance to centroid 2
    input  wire [17:0] dist3,   // distance to centroid 3

    // ── Winner output ──
    output wire [1:0]  cluster_id  // index of closest centroid (0-3)
);

    // ----------------------------------------------------------
    //  Level 1A : Compare dist0 vs dist1  (LEFT branch)
    //
    //  If dist0 <= dist1  →  winner is centroid 0
    //  Else               →  winner is centroid 1
    //
    //  Python: if d0 <= d1: id_A=0, min_A=d0  else: id_A=1, min_A=d1
    // ----------------------------------------------------------
    wire [17:0] min_A;
    wire [1:0]  id_A;

    assign min_A = (dist0 <= dist1) ? dist0 : dist1;
    assign id_A  = (dist0 <= dist1) ? 2'd0  : 2'd1;

    // ----------------------------------------------------------
    //  Level 1B : Compare dist2 vs dist3  (RIGHT branch)
    //  Runs IN PARALLEL with Level 1A - same clock cycle
    //
    //  Python: if d2 <= d3: id_B=2, min_B=d2  else: id_B=3, min_B=d3
    // ----------------------------------------------------------
    wire [17:0] min_B;
    wire [1:0]  id_B;

    assign min_B = (dist2 <= dist3) ? dist2 : dist3;
    assign id_B  = (dist2 <= dist3) ? 2'd2  : 2'd3;

    // ----------------------------------------------------------
    //  Level 2 : Final compare - min_A vs min_B
    //  This is the only serial step - unavoidable for 4 inputs.
    //  Critical path = 2 comparators deep (fast, ~1-2 LUTs).
    //
    //  Python: cluster_id = id_A if min_A <= min_B else id_B
    // ----------------------------------------------------------
    assign cluster_id = (min_A <= min_B) ? id_A : id_B;

endmodule