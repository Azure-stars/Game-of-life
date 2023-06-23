`timescale 1ns / 1ps
module mod_top_test();

// 仿真模块
reg clk_100m = 0;

wire [7:0]  video_blue ;
wire video_clk;
wire video_de;
wire [7:0]  video_green;
wire video_hsync;
wire [7:0]  video_red;
wire video_vsync;

always #5 clk_100m = ~clk_100m;

mod_top mod_i (
    .clk_100m(clk_100m),
    .video_blue(video_blue),
    .video_clk(video_clk),
    .video_de(video_de),
    .video_green(video_green),
    .video_hsync(video_hsync),
    .video_red(video_red),
    .video_vsync(video_vsync)
);

endmodule