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
    input wire clk,
    input wire vga_live,                // vga读取的像素是否存活
    output wire hsync,  
    output wire vsync,
    output reg [2 * WIDTH - 1:0] pos,   // 当前读取的位置
    output reg [7: 0] video_red,        // 红色像素，8位
    output reg [7: 0] video_green,      // 绿色像素，8位 
    output reg [7: 0] video_blue,       // 蓝色像素，8位
    output wire data_enable
);

reg[WIDTH - 1:0] hdata;
reg[WIDTH - 1:0] vdata;
// 当前一个像素大小为32
parameter PIXIV = HSIZE / P_PARAM_N;

initial begin
    hdata = 0;
    vdata = 0;
    pos = 1 / PIXIV;
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

// pos
always @ (posedge clk)
begin
    if (hdata == HMAX - 2) begin
        if (vdata == VMAX - 1) begin
            pos <= 0;
        end
        else if (vdata < VSIZE - 1) begin
            pos <= ((vdata + 1) / PIXIV) * P_PARAM_N;
        end
        else begin
            pos <= 0;
        end
    end
    else if (hdata == HMAX - 1) begin
        if (vdata == VMAX - 1) begin
            pos <= (1 / PIXIV);
        end
        else if (vdata < VSIZE - 1) begin
            pos <= ((vdata + 1) / PIXIV) * P_PARAM_N + 1 / PIXIV;
        end
        else begin
            pos <= 0;
        end
    end
    else begin
        if (hdata < HSIZE - 1) begin
            pos <= ((hdata + 2) / PIXIV) + (vdata / PIXIV) * P_PARAM_N;
        end
        else begin
            pos <= 0;
        end
    end
end

always @ (posedge clk)
begin
    if(hdata < HSIZE && vdata < VSIZE) begin
        if (vga_live) begin
            // 存活，为白色
            video_red   <= 8'b11111111;
            video_green <= 8'b11111111;
            video_blue  <= 8'b11111111;
        end
        else begin
            // 非黑即白
            video_red   <= 8'b00000000;
            video_green <= 8'b00000000;
            video_blue  <= 8'b00000000;
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
