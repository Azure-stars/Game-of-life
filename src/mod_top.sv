`timescale 1ns / 1ps
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
ip_pll u_ip_pll(
    .inclk0 (clk_in  ),
    .c0     (clk_vga )  // 50MHz 像素时钟
);
// 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz，显示渐变色彩条
reg[7:0] output_video_red;      // 输出的像素颜色
reg[7:0] output_video_blue;     // 输出的像素颜色
reg[7:0] output_video_green;    // 输出的像素颜色
reg[25:0] evo_cnt;              // 1Hz时钟的计数器
wire[2:0] ram_read_data;         // ram读取的数据
wire[2:0] ram_write_data;        // ram写入的数据
wire[2:0][23:0] ram_pos;         // ram的读写位置
reg clk_evo;                    // 1Hz时钟
wire [2:0] ram_rden;             // ram的读取使能
wire [2:0] ram_wden;             // ram的写入使能
wire vga_read_val;               // vga当前读取的值
wire [23:0] vga_pos;                   // vga当前读取的位置
wire round_rden;                // round读使能
wire round_wden;                // round写使能
wire [23:0]round_read_pos;                 // round当前读取的位置
wire [23:0]round_write_pos;                // round当前写入的位置
wire round_read_val;             // round当前读取的值
wire round_write_val;            // round当前即将写入的值，即某一个像素的演化后的状态
wire copy_rden;                 // copy时使用的读使能
wire copy_wden;                 // copy时使用的写使能       
wire copy_rpos;                 // copy时使用的读位置
wire copy_wpos;                 // copy时使用的写位置

parameter P_PARAM_N = 40;
parameter P_PARAM_M = 30;
initial begin
    evo_cnt = 0;
    clk_evo = 0;
end

always @ (posedge clk_vga) begin
    if (evo_cnt == 49999999) begin
        clk_evo <= ~clk_evo;
        evo_cnt <= 0;
    end else begin
        evo_cnt <= evo_cnt + 1;
    end
end

// 三个RAM
// 思路：第一个RAM用于演化模块读取的状态
// 第二个RAM用于演化模块的暂存模块
// 第三个RAM用于vga模块的显示模块

RAM_1_524288 ram1(
    .address(ram_pos[0]),
    .clock(clk_vga),
    .wren(ram_wden[0]),
    .rden(ram_rden[0]),
    .q(ram_read_data[0]),
    .data(ram_write_data[0])
);

RAM2_1_524288 ram_2(
    .address(ram_pos[1]),
    .clock(clk_vga),
    .wren(ram_wden[1]),
    .rden(ram_rden[1]),
    .q(ram_read_data[1]),
    .data(ram_write_data[1])
);

RAM_TEMP_1_524288 ram_temp(
    .address(ram_pos[2]),
    .clock(clk_vga),
    .wren(ram_wden[2]),
    .rden(ram_rden[2]),
    .q(ram_read_data[2]),
    .data(ram_write_data[2])
);

Round #(P_PARAM_M, P_PARAM_N, 12) round (
    .clk(clk_vga),
    .global_evo_en(clk_evo),
    .prev_status(round_read_val),
    .rden(round_rden),
    .wden(round_wden),
    .round_read_pos(round_read_pos),
    .round_write_pos(round_write_pos),
    .live(round_write_val),             // 仅在写使能为高时有效
    .copy_rden(copy_rden),
    .copy_wden(copy_wden)
);

assign video_clk = clk_vga;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1, P_PARAM_N, P_PARAM_M) vga800x600at50 (
    .clk(clk_vga),
    .vga_live(vga_read_val),
    .pos(vga_pos),
    .video_red(output_video_red),
    .video_green(output_video_blue),
    .video_blue(output_video_green),
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);

// RAM读写使能变化
assign ram_rden[2] = copy_rden;
assign ram_wden[2] = round_wden;
assign ram_rden[0] = clk_evo ? round_rden : 1;
assign ram_wden[0] = clk_evo ? copy_wden : 0;
assign ram_rden[1] = clk_evo ? 1 : round_rden;
assign ram_wden[1] = clk_evo ? 0 : copy_wden;

// RAM读写数据变化
assign round_read_val = clk_evo ? ram_read_data[0] : ram_read_data[1];
assign vga_read_val = clk_evo ? ram_read_data[1] : ram_read_data[0];
assign ram_write_data[0] = clk_evo ? ram_read_data[2] : 0;
assign ram_write_data[1] = clk_evo ? 0 : ram_read_data[2];
assign ram_write_data[2] = round_write_val;

// RAM地址变化
assign ram_pos[0] = clk_evo ? round_read_pos : vga_pos;
assign ram_pos[1] = clk_evo ? vga_pos : round_read_pos;    
assign ram_pos[2] = round_write_pos;

always_comb begin
    // 为了保证三者同时变化
    video_blue = output_video_blue;
    video_red = output_video_red;
    video_green = output_video_green;
end

endmodule
