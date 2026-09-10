// ============================================================
//  Module  : pixel_mem
//  Project : K-Means Hardware Accelerator
//  Step    : 5 of 7
// ------------------------------------------------------------
//  Purpose : Stores the full flattened image as a memory array
//            and streams one RGB pixel per clock to the pipeline.
//
//  Python equivalent (your export_mem.py):
//      pixels = image.reshape(-1, 3)   # 1024 pixels
//      with open("pixels.mem","w") as f:
//          for r,g,b in pixels:
//              f.write(f"{r:02X}{g:02X}{b:02X}\n")
//
//  Memory layout:
//      1024 locations (32×32 image flattened)
//      Each location = 24 bits = {R[7:0], G[7:0], B[7:0]}
//      Address 0 = top-left pixel, 1023 = bottom-right pixel
//
//  How $readmemh works:
//      At simulation start, Vivado reads pixels.mem from the
//      project directory. Each hex line loads one memory word.
//      Line 0 → mem[0], Line 1 → mem[1], ... Line 1023 → mem[1023]
//      Format: "FF8040" → R=FF, G=80, B=40
//
//  Operation:
//      When rd_en=1, the pixel at address addr is output
//      combinationally on the same cycle (synchronous read
//      with 1-cycle latency - FSM accounts for this).
//      addr is driven by the pixel counter in fsm_control.
//
//  Ports:
//      clk         - system clock
//      rd_en       - read enable from FSM (high during COMPUTE)
//      addr [9:0]  - pixel address (0-1023) from FSM counter
//      pixel_r     - R channel of current pixel
//      pixel_g     - G channel of current pixel
//      pixel_b     - B channel of current pixel
//      pixel_valid - high one cycle after rd_en (data is stable)
// ============================================================

`timescale 1ns / 1ps

module pixel_mem (
    input  wire        clk,
    input  wire        rd_en,       // read enable from FSM
    input  wire [9:0]  addr,        // pixel index 0-1023

    output reg  [7:0]  pixel_r,     // R channel out
    output reg  [7:0]  pixel_g,     // G channel out
    output reg  [7:0]  pixel_b,     // B channel out
    output reg         pixel_valid  // data valid flag (1 cycle after rd_en)
);

    // ----------------------------------------------------------
    //  Memory array - 1024 × 24-bit
    //  Packed as {R,G,B} in each word
    //
    //  $readmemh loads pixels.mem at simulation start.
    //  Place pixels.mem in:
    //    D:/programs/kmeans-hardware-accelerator/verilog/
    //    kmeans_accelerator/kmeans_accelerator.sim/sim_1/behav/xsim/
    //  OR use absolute path in $readmemh below.
    // ----------------------------------------------------------
    reg [23:0] mem [0:1023];

    initial begin
        $readmemh("pixels.mem", mem);
    end

    // ----------------------------------------------------------
    //  Synchronous read - 1-cycle latency
    //  On posedge clk when rd_en=1:
    //    → latch pixel at mem[addr] into output registers
    //    → assert pixel_valid next cycle
    //
    //  Python equivalent:
    //    pixel = pixels[addr]   →   R,G,B
    // ----------------------------------------------------------
    always @(posedge clk) begin
        if (rd_en) begin
            pixel_r     <= mem[addr][23:16];  // top 8 bits = R
            pixel_g     <= mem[addr][15:8];   // mid 8 bits = G
            pixel_b     <= mem[addr][7:0];    // low 8 bits = B
            pixel_valid <= 1'b1;
        end else begin
            pixel_valid <= 1'b0;
        end
    end

endmodule