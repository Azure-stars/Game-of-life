`timescale 1ns / 1ps
module mod_top (
  input wire clk_100m,
  input wire reset_n,            // 上电复位信号，低有效
  input wire reset_btn,          // 复位按钮，位于FPGA上左侧开关
  output reg [7: 0] video_red,   // 红色像素，8位
  output reg [7: 0] video_green, // 绿色像素，8位
  output reg [7: 0] video_blue,  // 蓝色像素，8位
  output wire        video_hsync, // 行同步（水平同步）信号
  output wire        video_vsync, // 场同步（垂直同步）信号
  output wire        video_clk,   // 像素时钟输出
  output wire        video_de,     // 行数据有效信号，用于区分消隐区
  
  
  input  wire        ps2_clock,   // PS/2 时钟信号
  input  wire        ps2_data,    // PS/2 数据信号
    
  output wire        sd_sclk,     // SPI 时钟
  output wire        sd_mosi,
  input  wire        sd_miso,
  output wire        sd_cs,       // SPI 片选，低有效
  input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
  input  wire        sd_wp, 

  // 调试
  output wire [31:0] leds,        // 32 位 LED 灯，输出 1 时点亮

  output wire [7: 0] dpy_digit,   // 七段数码管笔段信号
  output wire [7: 0] dpy_segment // 七段数码管位扫描信号

);
wire clk_in = clk_100m;

// PLL 分频演示，从输入产生不同频率的时钟
wire clk_vga;
ip_pll u_ip_pll(
    .inclk0 (clk_in  ),
    .c0     (clk_vga ),  // 50MHz 像素时钟	 
    .c1     (clk_ps2 ),  // 25MHz
    .c2     (clk_spi )   // 5MHz SPI SDcard 时钟
);
// 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz，显示渐变色彩条
reg[7:0] output_video_red;      // 输出的像素颜色
reg[7:0] output_video_blue;     // 输出的像素颜色
reg[7:0] output_video_green;    // 输出的像素颜色

reg[30:0] evo_cnt;              // 1Hz时钟的计数器
reg[3:0] evo_left_shift;


reg[4:0] ram_read_data;         // ram读取的数据
logic[4:0] ram_write_data;        // ram写入的数据
logic[4:0][23:0] ram_pos;         // ram的读写位置
reg clk_evo;                    // 1Hz时钟
logic [4:0] ram_rden;             // ram的读取使能
logic [4:0] ram_wden;             // ram的写入使能


logic vga_read_val;               // vga当前读取的值
reg [23:0] vga_pos;               // vga当前读取的位置


wire round_wden;                  // round写使能
logic [23:0]round_read_pos;      // round当前读取的位置
wire [23:0]round_write_pos;      // round当前写入的位置
wire round_read_val;             // round当前读取的值
reg round_write_val;            // round当前即将写入的值，即某一个像素的演化后的状态


reg init_label;                 // 是否进行初始化
wire init_read_val;              // init读取的值
reg init_write_val;             // init写入的值
logic [23:0]init_read_pos;
wire [23:0]init_write_pos;
reg init_finish;
wire init_wden; 
wire [23:0] preset_write_pos;
wire preset_wden;
wire preset_write_val;
reg preset_finish;
reg preset_rden;
reg preset_read_val;

reg [11:0]setting_hdata;          // 手动写入的位置        
reg [11:0]setting_vdata;    
reg [23:0]setting_pos;              
wire manual_flag;              // 是否处于手动写入的状态
reg [3:0] manual_forward;       // 手动按键设置方向
reg manual_wden;                // 手动写入的使能
reg manual_read_val;            // 手动读入的值
reg manual_write_val;           // 手动写入的值
reg manual_address;             // 手动写入的地址

parameter P_PARAM_N = 800;
parameter P_PARAM_M = 600;
parameter P_PARAM_K = 1;                // 列数对应的二进制次幂
parameter STATE_RST = 2'd0;            // 复位回到的状态，代表演化还没有开始
parameter STATE_RUNNING = 2'd1;        // 游戏正在运行中，此时`clk_evo`会进行计时变化
parameter STATE_PAUSE = 2'd2;          // 游戏暂停，此时停止演化
parameter STATE_SETTING = 2'd3;        // 手动设置状态
reg [1:0] state;
reg [1:0] prev_state;
reg start;                          // 本周期的开始按钮是否被按下
reg pause;                          // 本周期的暂停按钮是否被按下
reg clear;                          // 本周期的清空按钮是否被按下
reg manual;                         // 本周起的手动设置按钮是否被按下
reg modify;                         // 本周期的修改按钮是否被按下    
reg reload;                         // 重新加载当前文件

// 放缩平移
reg [15:0] shift_x;
reg [15:0] shift_y;
reg [3:0] scroll;

// 数码管显示数字
reg [31: 0] dpy_number;
                
initial begin   
    state = STATE_RST;
    prev_state = STATE_RST;
    init_finish = 0;
    preset_finish = 1;
    evo_cnt = 0;
    clk_evo = 0;
    setting_hdata = P_PARAM_N / 2;
    setting_vdata = P_PARAM_M / 2;
    setting_pos = setting_hdata + setting_vdata * P_PARAM_N;
end

always @ (posedge clk_vga, posedge reset_btn) begin
    if (reset_btn) begin
        evo_cnt <= 0;
        clk_evo <= 0;
        init_label <= ~init_label;
        state <= STATE_RST;
    end
    else begin
        if (state == STATE_RUNNING) begin
            if (evo_cnt >= (30'd2499999 << evo_left_shift)) begin
                if (clk_evo == 0) begin
                    clk_evo <= 1;
                end else begin
                    clk_evo <= 0;
                end
                evo_cnt <= 0;
            end else begin
                evo_cnt <= evo_cnt + 1;
            end
        end
        case (state)
            STATE_RST : begin
                if (start == 1) begin
                    evo_cnt <= 0;
                    clk_evo <= 0;
                    state <= STATE_PAUSE;
                end
                else if (manual == 1) begin
                    prev_state <= STATE_RST;
                    state <= STATE_SETTING;
                end
                else begin
                    state <= STATE_RST;
                end
            end
            STATE_RUNNING : begin
                // 暂时不支持清空和暂停
                if (pause == 1) begin
                   state <= STATE_PAUSE;
                end
                else if (clear == 1) begin
                    evo_cnt <= 0;
                    clk_evo <= 0;
                    init_label <= ~init_label;
                    state <= STATE_RST;
                end
                else begin
                   state <= STATE_RUNNING; 
                end
            end
            STATE_SETTING : begin
                if (manual == 0) begin
                    state <= prev_state;
                end
                else begin
                    if (manual_forward != 0) begin
                        case (manual_forward)
                            4'b0001 : begin
                                // A键
                                if (setting_hdata != 0) begin
                                    setting_pos <= setting_pos - 1;
                                    setting_hdata <= setting_hdata - 1;
                                end
                            end
                            4'b0010 : begin
                                // 按下W键
                                if (setting_vdata > 0) begin
                                    setting_pos <= setting_pos - P_PARAM_N;
                                    setting_vdata <= setting_vdata - 1;
                                end
                            end
                            4'b0100 : begin
                                // 按下S键
                                if (setting_vdata < P_PARAM_M - 1) begin
                                    setting_pos <= setting_pos + P_PARAM_N;
                                    setting_vdata <= setting_vdata + 1;
                                end
                            end
                            4'b1000 : begin
                                // 按下D键
                                if (setting_hdata < P_PARAM_N - 1) begin
                                    setting_pos <= setting_pos + 1;
                                    setting_hdata <= setting_hdata + 1;
                                end
                            end
                            default: begin
                            end 
                        endcase
                    end
                end
            end
            default: begin
                // STATE_PAUSE
                // 只有通过按钮才可以脱离暂停状态
                if (start == 1) begin
                    state <= STATE_RUNNING;
                end
                else if (clear == 1) begin
                    evo_cnt <= 0;
                    clk_evo <= 0;
                    init_label <= ~init_label;
                    state <= STATE_RST;
                end
                else if (manual == 1)begin
                    prev_state <= STATE_PAUSE;
                    state <= STATE_SETTING;
                end
                else begin
                    state <= STATE_PAUSE;
                end
            end
        endcase
    end
end


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

RAM_1_524288 ram_init(
    .address(ram_pos[4]),
    .clock(clk_vga),
    .wren(ram_wden[4]),
    .rden(ram_rden[4]),
    .q(ram_read_data[4]),
    .data(ram_write_data[4])
);

Round #(P_PARAM_M, P_PARAM_N, 12) round (
    .clk(clk_vga),
    .start(start),
    .rst(reset_btn),
    .global_evo_en(clk_evo),
    .prev_status(round_read_val),
    .wden(round_wden),
    .round_read_pos(round_read_pos),
    .round_write_pos(round_write_pos),
    .live(round_write_val)              // 仅在写使能为高时有效
);

Init #(P_PARAM_M, P_PARAM_N, 12) init(
    .clk(clk_vga),
    .start(init_label),
    .read_val(init_read_val),
    .write_en(init_wden),
    .write_val(init_write_val),
    .read_addr(init_read_pos),
    .write_addr(init_write_pos),
    .finish(init_finish)
);
assign manual_flag = (state == STATE_SETTING);
assign video_clk = clk_vga;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1, P_PARAM_N, P_PARAM_M) vga800x600at50 (
	.clk(clk_vga),
	.vga_live(vga_read_val),
	.setting_status(manual_flag),
	.setting_pos(setting_pos),
	.pos(vga_pos),
	.video_red(output_video_red),
	.video_green(output_video_blue),
	.video_blue(output_video_green),
	.hsync(video_hsync),
	.vsync(video_vsync),
	.data_enable(video_de),
	.shift_x   (shift_x),
	.shift_y   (shift_y),
	.scroll    (scroll)
);

// Manual #(P_PARAM_M, P_PARAM_N, 12) manual_io (
//     .clk(clk_vga),
//     .modify(modify),
// )

// // 键盘控制模块

reg [15:0] file_id;

KeyBoardController #(P_PARAM_N, P_PARAM_M) keyboard_controller (
	.clk_in    (clk_vga),
	.reset     (reset_btn),
	.ps2_clock (ps2_clock),
	.ps2_data  (ps2_data),
	.pause     (pause),
	.start     (start),
	.clear     (clear),
	.manual(manual),
	.setting(manual_forward),
	.file_id   (file_id),
	.reload     (reload),
	.shift_x   (shift_x),
	.shift_y   (shift_y),
	.scroll    (scroll),
	.evo_left_shift (evo_left_shift),
	.dpy_number (dpy_number)
);

// SD卡

wire read_file_finish;

SDCardReader sd_card_reader(
	.clk_spi            (clk_vga),
	.reset              (reset_btn),

	.sd_cs              (sd_cs),
	.sd_mosi            (sd_mosi),
	.sd_miso            (sd_miso),
	.sd_sclk            (sd_sclk),
	
	.clk_ram            (clk_vga),
	.address (preset_write_pos),
	.write_data    (preset_write_val),
	.rden    (preset_rden),
	.wren    (preset_wden),
	.read_data       (preset_read_val),
	
	.reload             (reload),
	.file_id            (file_id),
	.read_file_finish   (preset_finish)
);


// 七段数码管扫描
dpy_scan u_dpy_scan (
    .clk     (clk_in      ),
    .number  (dpy_number      ),
    .dp      (7'b0        ),
    .digit   (dpy_digit   ),
    .segment (dpy_segment )
);


// RAM读写使能变化
assign ram_rden[4] = 1;
assign ram_wden[4] = 0;

always_comb begin
    if (state == STATE_RST) begin
        if (init_finish == 0 && preset_finish == 0) begin
            ram_rden[0] = 0;
            ram_rden[1] = 0;
            ram_rden[2] = 0;
            ram_rden[3] = 0;
        end
        else if (manual == 1) begin
            ram_rden[0] = (clk_evo == 1) ? 1 : 0;
            ram_rden[1] = (clk_evo == 1) ? 1 : 0;
            ram_rden[2] = (clk_evo == 1) ? 0 : 1;
            ram_rden[3] = (clk_evo == 1) ? 0 : 1;
        end
        else begin
            ram_rden[0] = 1;
            ram_rden[1] = 1;
            ram_rden[2] = 1;
            ram_rden[3] = 1;
        end
        if (init_finish == 0) begin
            ram_wden[0] = init_wden;
            ram_wden[1] = init_wden;
            ram_wden[2] = init_wden;
            ram_wden[3] = init_wden;
        end
        else if (preset_finish == 0) begin
            ram_wden[0] = preset_wden;
            ram_wden[1] = preset_wden;
            ram_wden[2] = preset_wden;
            ram_wden[3] = preset_wden;
        end
        else if (manual == 1) begin
            // 交给了manual模块
            ram_wden[0] = (clk_evo == 1) ? 0 : manual_wden;
            ram_wden[1] = (clk_evo == 1) ? 0 : manual_wden;
            ram_wden[2] = (clk_evo == 1) ? manual_wden : 0;
            ram_wden[3] = (clk_evo == 1) ? manual_wden : 0;
        end
        else begin
            ram_wden[0] = 0;
            ram_wden[1] = 0;
            ram_wden[2] = 0;
            ram_wden[3] = 0;
        end
    end
    else begin
        ram_rden[0] = (clk_evo == 1) ? 1 : 0;
        ram_rden[1] = (clk_evo == 1) ? 1 : 0;
        ram_rden[2] = (clk_evo == 1) ? 0 : 1;
        ram_rden[3] = (clk_evo == 1) ? 0 : 1;
        ram_wden[0] = (clk_evo == 1) ? 0 : round_wden;
        ram_wden[1] = (clk_evo == 1) ? 0 : round_wden;
        ram_wden[2] = (clk_evo == 1) ? round_wden : 0;
        ram_wden[3] = (clk_evo == 1) ? round_wden : 0;
    end
end

// RAM读写数据变化
assign round_read_val = (clk_evo == 1) ? ram_read_data[0] : ram_read_data[2];
// assign vga_read_val = (clk_evo == 1) ? ram_read_data[1] : ram_read_data[3];
assign init_read_val = ram_read_data[4];
always_comb begin
    if (state == STATE_RST && (init_finish == 0 || preset_finish == 0)) begin
        vga_read_val = 8'b11111111;
    end
    else begin
        vga_read_val = (clk_evo == 1) ? ram_read_data[1] : ram_read_data[3];
    end
end

// assign vga_read_val = (pause == 1) ?  1 : 0;

// 后续实现预设写入则使用注释代码，而非当前代码，需要对输出值进行控制
always_comb begin
    if (state == STATE_RST) begin
        if (init_finish == 0) begin
            ram_write_data[0] = init_write_val;
            ram_write_data[1] = init_write_val;
            ram_write_data[2] = init_write_val;
            ram_write_data[3] = init_write_val;
        end
        else if (preset_finish == 0) begin
            ram_write_data[0] = preset_write_val;
            ram_write_data[1] = preset_write_val;
            ram_write_data[2] = preset_write_val;
            ram_write_data[3] = preset_write_val;
        end
        else begin
            // 交给manual模块
            ram_write_data[0] = manual_write_val;
            ram_write_data[1] = manual_write_val;
            ram_write_data[2] = manual_write_val;
            ram_write_data[3] = manual_write_val;
        end
    end
    else begin
        ram_write_data[0] = round_write_val;
        ram_write_data[1] = round_write_val;
        ram_write_data[2] = round_write_val;
        ram_write_data[3] = round_write_val;
    end
end
assign ram_write_data[4] = 0;
// RAM地址变化
assign ram_pos[4] = init_read_pos;

always_comb begin
    if (state == STATE_RST) begin
        if (init_finish == 0) begin
            ram_pos[0] = init_write_pos;
            ram_pos[1] = init_write_pos;
            ram_pos[2] = init_write_pos;
            ram_pos[3] = init_write_pos;
        end
        else if (preset_finish == 0) begin
            ram_pos[0] = preset_write_pos;
            ram_pos[1] = preset_write_pos;
            ram_pos[2] = preset_write_pos;
            ram_pos[3] = preset_write_pos;
        end
        else begin
            ram_pos[0] = manual_address;
            ram_pos[1] = (clk_evo == 1) ? vga_pos : manual_address;
            ram_pos[2] = manual_address;
            ram_pos[3] = (clk_evo == 1) ? manual_address : vga_pos;
        end
    end
    else begin
        ram_pos[0] = (clk_evo == 1) ? round_read_pos : round_write_pos;
        ram_pos[1] = (clk_evo == 1) ? vga_pos : round_write_pos;
        ram_pos[2] = (clk_evo == 1) ? round_write_pos : round_read_pos;
        ram_pos[3] = (clk_evo == 1) ? round_write_pos : vga_pos;
    end
end

always_comb begin
    // 为了保证三者同时变化
    video_blue = output_video_blue;
    video_red = output_video_red;
    video_green = output_video_green;
end 

// 调试
assign leds[31:19] = {2'b00, setting_pos[11:0]};
assign leds[18:0] = { file_id[7:0], manual_forward[3:0], manual, preset_finish, init_finish, state, pause, start, clear};  // read_file_finish

endmodule
