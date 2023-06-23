`timescale 1ns / 1ps
//
// WIDTH: bits in register hdata & vdata
// HSIZE: horizontal size of visible field 
// HFP: horizontal front of pulse
// HSP: horizontal stop of pulse
// HMAX: horizontal max size of value
// VSIZE: vertical size of visible field 
// VFP: vertical front of pulse
// VSP: vertical stop of pulse
// VMAX: vertical max size of value
// HSPP: horizontal synchro pulse polarity (0 - negative, 1 - positive)
// VSPP: vertical synchro pulse polarity (0 - negative, 1 - positive)
//
module vga
#(parameter WIDTH = 0, HSIZE = 0, HFP = 0, HSP = 0, HMAX = 0, VSIZE = 0, VFP = 0, VSP = 0, VMAX = 0, HSPP = 0, VSPP = 0, P_PARAM_N = 0, P_PARAM_M = 0, BLOCK_LEN = 1)
(

    input wire [15:0] shift_x,                          // 用于移动的偏移量横坐标
    input wire [15:0] shift_y,                          // 用于移动的偏移量纵坐标
    input wire [3:0] scroll,                            // 用于缩放的参数

    input wire clk,                                     // 时钟
    input wire [BLOCK_LEN - 1: 0] vga_live,             // 当前块的像素是否存活
	 input wire [31:0] display_color_id,                // 当前显示的背景色的编号
	 
    output wire hsync,                                  // 水平同步信号
    output wire vsync,                                  // 垂直同步信号
    output reg [2 * WIDTH - 1:0] output_pos,            // 当前读取的像素对应的块编号
    output reg [7: 0] video_red,                        // 红色像素，8位
    output reg [7: 0] video_green,                      // 绿色像素，8位 
    output reg [7: 0] video_blue,                       // 蓝色像素，8位
    output wire data_enable                             // 数据使能信号
);
reg[2*WIDTH - 1:0] prev_pos;        // 上一个周期时读取的像素位置，由于读取存在时延导致需要记录前一个位置
reg[2*WIDTH - 1:0] pos;             // 当前读取的RAM的像素的编号，用来计算所在的块
reg [7:0] cell_color [3:0][2:0];    // 每个块的颜色，共4个块，每个块有3个颜色
reg [7:0] background_color [3:0][2:0];  // 每个块的背景颜色，共4个块，每个块有3个颜色

reg[WIDTH - 1:0] hdata;             // 当前读取的横坐标
reg[WIDTH - 1:0] vdata;             // 当前读取的纵坐标

initial begin
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
    hdata = 0;
    vdata = 0;
    video_green = 0 ;
    video_blue = 0;
    video_red = 0;
end

// 由于块长固定为32，因此可以直接用位移来计算块编号
assign output_pos = pos[2*WIDTH - 1:5];

// WIDTH与整个屏幕有关
// HSIZE代表了可见域的宽度
// HFP = HSIZE + FRONT_PROCH，其中FRONT_PROCH代表了图像右边的部分不可见区域的宽度
// HSP = HFP + SYNC PULSE，其中SYNC_PULSE代表了同步信号区间，也是不可见的，
// HMAX = HSP + BACK_PROCH，其中后沿代表了图像左边部分的不可见区域宽度  
// hdata
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
        if (vdata < VSIZE - 1) begin
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N;
        end
        else begin
            // vdata为VMAX的情况被包含了
            pos <= 0;
        end
    end
    else if (hdata == HMAX - 1) begin
        if (vdata < VSIZE - 1) begin
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y + 1) * P_PARAM_N + 1;
        end
        else if (vdata == VMAX - 1) begin
            pos <= 1;
        end
        else begin
            pos <= 0;
        end
    end
    else begin
        pos <= 0;
    end
    prev_pos <= pos;
    // pos <= ((vdata >> scroll) + shift_y) * P_PARAM_N + ((hdata >> scroll) + shift_x);
    cell_color[0][0] <= {pos[4:0], pos[7:5]};
    cell_color[0][1] <= {pos[2:0], pos[7:3]};
    cell_color[2][0] <= {1'b0, pos[3:1], pos[7:4]};
    cell_color[2][2] <= {1'b1, pos[3:0], pos[7:5]};
    cell_color[3][1] <= {1'b1, pos[3:0], pos[7:5]};
    cell_color[3][2] <= {1'b0, pos[3:1], pos[7:4]};
    // cell_color[0] <= {1'b1, pos[4:1], pos[7:5]};
    // cell_color[1] <= {1'b1, pos[2:1], pos[7:3]};
    // cell_color[2] <= {1'b1, pos[6:0]};
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
// assign data_enable = 1;
endmodule
