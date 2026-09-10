`timescale 1ns / 1ps

module dist_unit (
    input  wire [7:0] pixel_r,
    input  wire [7:0] pixel_g,
    input  wire [7:0] pixel_b,

    input  wire [7:0] cent_r,
    input  wire [7:0] cent_g,
    input  wire [7:0] cent_b,

    output wire [17:0] dist_sq
);

    wire signed [8:0] dr;
    wire signed [8:0] dg;
    wire signed [8:0] db;

    wire [17:0] dr_sq;
    wire [17:0] dg_sq;
    wire [17:0] db_sq;

    assign dr = $signed({1'b0, pixel_r}) - $signed({1'b0, cent_r});
    assign dg = $signed({1'b0, pixel_g}) - $signed({1'b0, cent_g});
    assign db = $signed({1'b0, pixel_b}) - $signed({1'b0, cent_b});

    assign dr_sq = dr * dr;
    assign dg_sq = dg * dg;
    assign db_sq = db * db;

    assign dist_sq = dr_sq + dg_sq + db_sq;

endmodule
