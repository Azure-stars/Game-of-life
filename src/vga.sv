`timescale 1ns / 1ps

// WIDTH: 寄存器hdata和vdata中的位宽，和屏幕大小有关
// HSIZE: 行同步信号有效图像长度
// HFP: HSIZE + FRONT_PROCH，其中FRONT_PROCH代表了图像右边的部分不可见区域的宽度
// HSP: HFP + SYNC PULSE，其中SYNC_PULSE代表了同步信号区间，也是不可见的，
// HMAX = HSP + BACK_PROCH，其中后沿代表了图像左边部分的不可见区域宽度  
// VSIZE: 列同步信号有效图像长度
// VFP: VSIZE + FRONT_PROCH，其中FRONT_PROCH代表了图像下边的部分不可见区域的宽度
// VSP: VFP + SYNC PULSE，其中SYNC_PULSE代表了同步信号区间，也是不可见的，
// VMAX = VSP + BACK_PROCH，其中后沿代表了图像上边部分的不可见区域宽度
// HSPP: 水平同步脉冲极性（0 - 负极性，1 - 正极性）
// VSPP: 垂直同步脉冲极性（0 - 负极性，1 - 正极性）
// 上述参数均可参照 VGA 文档进行设置
// P_PARAM_M: 可视屏幕像素行数
// P_PARAM_N: 可视屏幕像素列数
// BLOCK_LEN: 每个块的长度，这里的块需要和主逻辑配合，因为传入的演化像素是以块为单位进行计算的。但是展示 VGA 的时候依然是一个个像素展示
module vga
#(parameter WIDTH = 0, HSIZE = 0, HFP = 0, HSP = 0, HMAX = 0, VSIZE = 0, VFP = 0, VSP = 0, VMAX = 0, HSPP = 0, VSPP = 0, P_PARAM_N = 0, P_PARAM_M = 0, BLOCK_LEN = 1)
(

    input wire [15:0] shift_x,                          // 用于移动的偏移量横坐标
    input wire [15:0] shift_y,                          // 用于移动的偏移量纵坐标
    input wire [3:0] scroll,                            // 用于缩放的参数

    input wire clk,                                     // 时钟
    input wire [BLOCK_LEN - 1: 0] vga_live,             // 当前块的像素是否存活
	input wire [31:0] display_color_id,                 // 当前显示的背景色的编号
	 
    output wire hsync,                                  // 水平同步信号
    output wire vsync,                                  // 垂直同步信号
    output reg [2 * WIDTH - 1:0] output_pos,            // 当前读取的像素对应的块编号
    output reg [7: 0] video_red,                        // 红色像素，8位
    output reg [7: 0] video_green,                      // 绿色像素，8位 
    output reg [7: 0] video_blue,                       // 蓝色像素，8位
    output wire data_enable                             // 数据使能信号
);
reg[2*WIDTH - 1:0] prev_pos;                // 上一个周期时读取的像素位置，由于读取存在时延导致需要记录前一个位置
reg[2*WIDTH - 1:0] pos;                     // 当前读取的RAM的像素的编号，用来计算所在的块
reg [7:0] cell_color [3:0][2:0];            // 每个块的颜色，共4个块，每个块有3个颜色
reg [7:0] background_color [3:0][2:0];      // 每个块的背景颜色，共4个块，每个块有3个颜色

reg[WIDTH - 1:0] hdata;                     // 当前读取的横坐标
reg[WIDTH - 1:0] vdata;                     // 当前读取的纵坐标

initial begin
    // 初始化细胞颜色和背景颜色
    // 第一维代表不同的颜色风格，第二维代表RGB
    // 不同的细胞颜色和背景颜色可以组成不同的风格
    cell_color[0][0] <= 8'd255;
    cell_color[0][1] <= 8'd255;
    cell_color[0][2] <= 8'd255;
    cell_color[1][0] <= 8'd255;
    cell_color[1][1] <= 8'd255;
    cell_color[1][2] <= 8'd255;
    cell_color[2][0] <= 8'd255;
    cell_color[2][1] <= 8'd255;
    cell_color[2][2] <= 8'd255;
    cell_color[3][0] <= 8'd255;
    cell_color[3][1] <= 8'd128;
    cell_color[3][2] <= 8'd128;

    background_color[0][0] <= 8'd0;
    background_color[0][1] <= 8'd0;
    background_color[0][2] <= 8'd0;
    background_color[1][0] <= 8'd23;
    background_color[1][1] <= 8'd63;
    background_color[1][2] <= 8'd63;
    background_color[2][0] <= 8'd63;
    background_color[2][1] <= 8'd23;
    background_color[2][2] <= 8'd63;
    background_color[3][0] <= 8'd63;
    background_color[3][1] <= 8'd63;
    background_color[3][2] <= 8'd23;

    // 初始化 hdata 和 vdata 寄存器
    hdata = 0;
    vdata = 0;
    video_green = 0 ;
    video_blue = 0;
    video_red = 0;
end

// 由于块长固定为 32，因此可以直接用位移来计算块编号
assign output_pos = pos[2*WIDTH - 1:5];

always @ (posedge clk)
begin
    if (hdata == (HMAX - 1))
        hdata <= 0;
    else
        hdata <= hdata + 1;
end

// vdata
always @ (posedge clk)
begin
    if (hdata == (HMAX - 1)) 
    begin
        if (vdata == (VMAX - 1))
            vdata <= 0;
        else
            vdata <= vdata + 1;
    end
end

initial begin
    pos = 0;
end
always @ (posedge clk) begin
    if (hdata < HSIZE) begin
        // 注意考虑偏移和放缩
        pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N + ((hdata[WIDTH - 1:0] >> scroll) + shift_x) + 2;  // {vdata, 9'd0} + {vdata, 8'd0} + {vdata, 5'd0}
    end
    else if (hdata == HMAX - 2) begin
        // 即将进入下一行
        if (vdata < VSIZE - 1) begin
            // 如果现在不是可视区域的最后一行，那么仍然要更新 pos 为下一行可视区域第 0 列的位置
            // 但是要考虑偏移和放缩
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N;
        end
        else begin
            // 否则是不可视区域，直接置为 0 即可。
            // 注意，如果 vdata == VMAX - 1，那么接下来会进入可视区域的第一行第 0 列，也被这个操作覆盖了
            pos <= 0;
        end
    end
    else if (hdata == HMAX - 1) begin
        // 提前计算下一行的第二个元素
        if (vdata < VSIZE - 1) begin
            // 如果现在不是可视区域的最后一行，那么仍然要更新 pos 为下一行可视区域第 1 列的位置
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y + 1) * P_PARAM_N + 1;
        end
        else if (vdata == VMAX - 1) begin
            // 如果现在是整个区域（注意不是可视区域）最后一行，那么直接置为 1，因为接下来即将绕回到第一行
            pos <= 1;
        end
        else begin
            pos <= 0;
        end
    end
    else begin
        pos <= 0;
    end

    // 记录本周期的 pos，因为读取 RAM 存在时延，只有到了下一个周期才能读到像素存活情况
    prev_pos <= pos;
    
    // 同理 cell_color 也要提前计算，下一个周期刚好更新，和像素存活情况对应
    cell_color[0][0] <= {pos[4:0], pos[7:5]};
    cell_color[0][1] <= {pos[2:0], pos[7:3]};
    cell_color[2][0] <= {1'b0, pos[3:1], pos[7:4]};
    cell_color[2][2] <= {1'b1, pos[3:0], pos[7:5]};
    cell_color[3][1] <= {1'b1, pos[3:0], pos[7:5]};
    cell_color[3][2] <= {1'b0, pos[3:1], pos[7:4]};

end
always @ (posedge clk)
begin
    if(hdata < HSIZE && vdata < VSIZE) begin
        if (vga_live[prev_pos[4:0]]) begin
            // 存活
            video_red   <= cell_color[display_color_id[1:0]][0];
            video_green <= cell_color[display_color_id[1:0]][1];
            video_blue  <= cell_color[display_color_id[1:0]][2];
        end
        else begin
            // 死亡
            video_red   <= background_color[display_color_id[3:2]][0];
            video_green <= background_color[display_color_id[3:2]][1];
            video_blue  <= background_color[display_color_id[3:2]][2]; 
        end
    end
    else begin
        video_red   <= 8'b00000000;
        video_green <= 8'b00000000;
        video_blue  <= 8'b00000000;
    end
end


// hsync & vsync & blank
assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
assign data_enable = ((hdata < HSIZE) & (vdata < VSIZE));
endmodule
