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
#(parameter WIDTH = 0, HSIZE = 0, HFP = 0, HSP = 0, HMAX = 0, VSIZE = 0, VFP = 0, VSP = 0, VMAX = 0, HSPP = 0, VSPP = 0, P_PARAM_N = 0, P_PARAM_M = 0)
(

    input wire [15:0] shift_x,
    input wire [15:0] shift_y,
    input wire [3:0] scroll,

    input wire clk,
    input wire vga_live,                // vga读取的像素是否存活
    input wire setting_status,          // 是否为手动选中状态
    input wire [2 * WIDTH - 1:0] setting_pos,      // 手动选中的位置
    output wire hsync,  
    output wire vsync,
    output reg [2 * WIDTH - 1:0] pos,   // 当前读取的位置
    output reg [7: 0] video_red,        // 红色像素，8位
    output reg [7: 0] video_green,      // 绿色像素，8位 
    output reg [7: 0] video_blue,       // 蓝色像素，8位
    output wire data_enable
);

reg [7:0] cell_color [2:0];

reg[WIDTH - 1:0] hdata;
reg[WIDTH - 1:0] vdata;
// 当前一个像素大小为32
parameter PIXIV = HSIZE / P_PARAM_N;
parameter ALL_COL = HMAX / PIXIV;
initial begin
    cell_color[0] <= 8'd255;
    cell_color[1] <= 8'd255;
    cell_color[2] <= 8'd255;
    hdata = 0;
    vdata = 0;
    video_green = 0 ;
    video_blue = 0;
    video_red = 0;
end

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
        pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N + ((hdata[WIDTH - 1:0] >> scroll) + shift_x) + 2;  // {vdata, 9'd0} + {vdata, 8'd0} + {vdata, 5'd0}
    end
    else if (hdata == HMAX - 2) begin
        if (vdata < VSIZE - 1) begin
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N + 1;
        end
        else begin
            // vdata为VMAX的情况被包含了
            pos <= 0;
        end
    end
    else if (hdata == HMAX - 1) begin
        if (vdata < VSIZE - 1) begin
            pos <= ((vdata[WIDTH - 1:0] >> scroll) + shift_y) * P_PARAM_N + 2;
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
	 cell_color[0] <= {pos[4:0], pos[7:5]};
	 cell_color[1] <= {pos[2:0], pos[7:3]};
	 // cell_color[0] <= {1'b1, pos[4:1], pos[7:5]};
	 // cell_color[1] <= {1'b1, pos[2:1], pos[7:3]};
	 // cell_color[2] <= {1'b1, pos[6:0]};
end
always @ (posedge clk)
begin
    if(hdata < HSIZE && vdata < VSIZE) begin
        if (vga_live) begin
            // 存活，为白色
            if (setting_status && setting_pos == pos) begin
                video_red <= 8'b11111111;
                video_green <= 8'b00000000;
                video_blue <= 8'b00000000;
            end
            else begin
                // video_red   <= 8'b11111111;
                // video_green <= 8'b11111111;
                // video_blue  <= 8'b11111111;
                video_red   <= cell_color[0];
                video_green <= cell_color[1];
                video_blue  <= cell_color[2];
            end
        end
        else begin
            // 非黑即白
            if (setting_status && setting_pos == pos) begin
                video_red <= 8'b00000000;
                video_green <= 8'b00000000;
                video_blue <= 8'b11111111;
            end
            else begin
                video_red   <= 8'b00000000;
                video_green <= 8'b00000000;
                video_blue  <= 8'b00000000; 
            end
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
