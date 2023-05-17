`timescale 1ns / 1ps
module mod_top (
  input wire clk_100m,
  input wire clock_btn,          // 右侧微动开关，推荐作为手动时钟，带消抖电路，按下时为 1
  input wire reset_btn,          // 复位按钮，位于FPGA上左侧开关
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
reg[30:0] evo_cnt;              // 1Hz时钟的计数器
reg[3:0] ram_read_data;         // ram读取的数据
wire[3:0] ram_write_data;        // ram写入的数据
wire[3:0][23:0] ram_pos;         // ram的读写位置
reg clk_evo;                    // 1Hz时钟
wire [3:0] ram_rden;             // ram的读取使能
wire [3:0] ram_wden;             // ram的写入使能
wire vga_read_val;               // vga当前读取的值
reg [23:0] vga_pos;                   // vga当前读取的位置
wire round_wden;                // round写使能
wire [23:0]round_read_pos;                 // round当前读取的位置
wire [23:0]round_write_pos;                // round当前写入的位置
wire round_read_val;             // round当前读取的值
reg round_write_val;            // round当前即将写入的值，即某一个像素的演化后的状态
parameter P_PARAM_N = 400;
parameter P_PARAM_M = 300;
initial begin
    evo_cnt = 0;
    clk_evo = 0;
end

parameter STATE_RST = 0;            // 复位回到的状态，代表演化还没有开始
parameter STATE_RUNNING = 1;        // 游戏正在运行中，此时`clk_evo`会进行计时变化
parameter STATE_PAUSE = 2;          // 游戏暂停，此时停止演化

reg [1:0] state;
reg prev_start;                     // 上一个周期的开始按钮是否被按下


initial begin   
    prev_start = 0;
    state = STATE_RST;  
end

always @ (posedge clk_vga, posedge reset_btn) begin
    prev_start <= clock_btn;
    // prev_pause <= pause;
    // prev_clear <= clear;

    if (reset_btn) begin
        evo_cnt <= 0;
        clk_evo <= 0;
        state <= STATE_RST;
    end
    else begin
        case (state)
            STATE_RST : begin
                if (clock_btn == 1) begin
                    state <= STATE_RUNNING;
                end
                else begin
                    evo_cnt <= 0;
                    clk_evo <= 0;
                    state <= STATE_RST;
                end
            end 
            STATE_RUNNING : begin
                // 暂时不支持清空和暂停
                // if (prev_pause != pause && pause == 1) begin
                //    state <= STATE_PAUSE;
                // end
                // else if (prev_clear != clear && clear == 1) begin
                //    state <= STATE_RST;
                // end
                // else begin
                if (evo_cnt == 4999999) begin
                    if (clk_evo == 0) begin
                        clk_evo <= 1;
                    end else begin
                        clk_evo <= 0;
                    end
                    evo_cnt <= 0;
                end else begin
                    evo_cnt <= evo_cnt + 1;
                end
                state <= STATE_RUNNING; 
                // end
            end
            default: begin
                // STATE_PAUSE
                // 只有通过按钮才可以脱离暂停状态
                if (prev_start != clock_btn && clock_btn == 1) begin
                    state <= STATE_RUNNING;
                end
                // else if (prev_clear != clear && clear == 1) begin
                //    evo_cnt <= 0;
                //    clk_evo <= 0;
                //    state <= STATE_RST;
                // end
                else begin
                    state <= STATE_PAUSE;
                end
            end
        endcase
    end
end

// 三个RAM
// 思路：第一个RAM用于演化模块读取的状态
// 第二个RAM用于演化模块的暂存模块
// 第三个RAM用于vga模块的显示模块

// clk_evo为高电平时的演化模块
RAM_1_524288 ram1(
    .address(ram_pos[0]),
    .clock(clk_vga),
    .wren(ram_wden[0]),
    .rden(ram_rden[0]),
    .q(ram_read_data[0]),
    .data(ram_write_data[0])
);

// clk_evo为高电平时的读取模块
RAM_1_524288 ram_2(
    .address(ram_pos[1]),
    .clock(clk_vga),
    .wren(ram_wden[1]),
    .rden(ram_rden[1]),
    .q(ram_read_data[1]),
    .data(ram_write_data[1])
);

// clk_evo为低电平时的演化模块
RAM_1_524288 ram_3(
    .address(ram_pos[2]),
    .clock(clk_vga),
    .wren(ram_wden[2]),
    .rden(ram_rden[2]),
    .q(ram_read_data[2]),
    .data(ram_write_data[2])
);

// clk_evo为低电平时的读取模块
RAM_1_524288 ram_4(
    .address(ram_pos[3]),
    .clock(clk_vga),
    .wren(ram_wden[3]),
    .rden(ram_rden[3]),
    .q(ram_read_data[3]),
    .data(ram_write_data[3])
);

Round #(P_PARAM_M, P_PARAM_N, 12) round (
    .clk(clk_vga),
    .global_evo_en(clk_evo),
    .prev_status(round_read_val),
    .wden(round_wden),
    .round_read_pos(round_read_pos),
    .round_write_pos(round_write_pos),
    .live(round_write_val)              // 仅在写使能为高时有效
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

// 高电平演化
assign ram_rden[0] = (clk_evo == 1) ? 1 : 0;
assign ram_wden[0] = (clk_evo == 1) ? 0 : round_wden;
// 高电平读取
assign ram_rden[1] = (clk_evo == 1) ? 1 : 0;
assign ram_wden[1] = (clk_evo == 1) ? 0 : round_wden;

// 低电平演化
assign ram_rden[2] = (clk_evo == 1) ? 0 : 1;
assign ram_wden[2] = (clk_evo == 1) ? round_wden : 0;
// 低电平读取
assign ram_rden[3] = (clk_evo == 1) ? 0 : 1;
assign ram_wden[3] = (clk_evo == 1) ? round_wden : 0;

// RAM读写数据变化
assign round_read_val = (clk_evo == 1) ? ram_read_data[0] : ram_read_data[2];
assign vga_read_val = (state == STATE_RST) ? 1 :((clk_evo == 1) ? ram_read_data[1] : ram_read_data[3]);     // 清空是假暂停，此时vga采样全为0，但是RAM值不变。
assign ram_write_data[0] = round_write_val;
assign ram_write_data[1] = round_write_val;
assign ram_write_data[2] = round_write_val;
assign ram_write_data[3] = round_write_val;

// RAM地址变化
assign ram_pos[0] = (clk_evo == 1) ? round_read_pos : round_write_pos;
assign ram_pos[1] = (clk_evo == 1) ? vga_pos : round_write_pos;
assign ram_pos[2] = (clk_evo == 1) ? round_write_pos : round_read_pos;
assign ram_pos[3] = (clk_evo == 1) ? round_write_pos : vga_pos;
always_comb begin
    // 为了保证三者同时变化
    video_blue = output_video_blue;
    video_red = output_video_red;
    video_green = output_video_green;
end 


endmodule
