module mod_top (
  input wire clk_100m,
  output reg [7: 0] video_red,   // 红色像素，8位
  output reg [7: 0] video_green, // 绿色像素，8位
  output reg [7: 0] video_blue,  // 蓝色像素，8位
  output wire        video_hsync, // 行同步（水平同步）信号
  output wire        video_vsync, // 场同步（垂直同步）信号
  output wire        video_clk,   // 像素时钟输出
  output wire        video_de     // 行数据有效信号，用于区分消隐区
);
wire clk_in = clk_100m;

// PLL 分频演示，从输入产生不同频率的时钟
wire clk_vga;
PLL_75MHz u_ip_pll(
    .inclk0 (clk_in  ),
    .c0     (clk_vga )  // 75MHz 像素时钟
);
// 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz，显示渐变色彩条
wire [11:0] hdata;  // 当前横坐标
wire [11:0] vdata;  // 当前纵坐标

assign video_clk = clk_vga;
vga #(12, 512, 1048, 1184, 1328, 512, 771, 777, 806, 1, 1) vga800x600at75 (
    .clk(clk_vga), 
    .hdata(hdata), //横坐标
    .vdata(vdata), //纵坐标
    .video_red(video_red),
    .video_green(video_green),
    .video_blue(video_blue),
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);

endmodule
