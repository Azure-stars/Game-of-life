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
#(parameter WIDTH = 0, HSIZE = 0, HFP = 0, HSP = 0, HMAX = 0, VSIZE = 0, VFP = 0, VSP = 0, VMAX = 0, HSPP = 0, VSPP = 0)
(
    input wire clk,
    output wire hsync,
    output wire vsync,
    output reg [WIDTH - 1:0] hdata, // 水平数据，WIDTH位
    output reg [WIDTH - 1:0] vdata, // 垂直数据，WIDTH位
    output reg [7: 0] video_red,   // 红色像素，8位
    output reg [7: 0] video_green, // 绿色像素，8位
    output reg [7: 0] video_blue,  // 蓝色像素，8位
    output wire data_enable
);

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

reg [1:0] color = 3;        // 当前位置的像素颜色

reg [WIDTH - 1:0] real_hdata = 0;   // 真正输出颜色区域的横坐标，与ROM大小有关
reg [WIDTH - 1:0] real_vdata = 0;   // 真正输出颜色区域的纵坐标，与ROM大小有关

always_comb begin 
    if (hdata >= 512) begin
        real_hdata = 0;
    end
    else begin
        real_hdata = hdata;
    end
    if (vdata >= 512) begin
        real_vdata = 0;
    end
    else begin
        real_vdata = vdata;
    end
end 

ROM_2_65536 rom_2_65536 (
    .address (real_vdata * 512 + real_hdata),
    .clock (clk),
    .q (color)
);

always_comb begin
    if (hdata < 512 && hdata < 512) begin
        case (color)
            2'b01: begin
                video_red   = 8'b11111111;
                video_green = 8'b00000000;
                video_blue  = 8'b00000000;
            end
            2'b10: begin
                video_red   = 8'b00000000;
                video_green = 8'b11111111;
                video_blue  = 8'b00000000;
            end
            2'b11: begin
                video_red   = 8'b11111111;
                video_green = 8'b11111111;
                video_blue  = 8'b11111111;
            end
            default: begin
                video_red   = 8'b00000000;
                video_green = 8'b00000000;
                video_blue  = 8'b11111111;
            end
        endcase
    end
    else begin
        video_red   = 8'b11111111;
        video_green = 8'b11111111;
        video_blue  = 8'b11111111;
    end
    
end


// hsync & vsync & blank
assign hsync = ((hdata >= HFP) && (hdata < HSP)) ? HSPP : !HSPP;
assign vsync = ((vdata >= VFP) && (vdata < VSP)) ? VSPP : !VSPP;
assign data_enable = ((hdata < HSIZE) & (vdata < VSIZE));

endmodule
