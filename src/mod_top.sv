module mod_top (
    // 时钟、复位
    input  wire clk_100m,           // 100M 输入时钟
    input  wire reset_n,            // 上电复位信号，低有效

    // 开关、LED 等
    input  wire clock_btn,          // 左侧微动开关，推荐作为手动时钟，带消抖电路，按下时为 1
    input  wire reset_btn,          // 右侧微动开关，推荐作为手动复位，带消抖电路，按下时为 1
    input  wire [3:0]  touch_btn,   // 四个按钮开关，按下时为 0
    input  wire [15:0] dip_sw,      // 16 位拨码开关，拨到 “ON” 时为 0
    output wire [31:0] leds,        // 32 位 LED 灯，输出 1 时点亮
    output wire [7: 0] dpy_digit,   // 七段数码管笔段信号
    output wire [7: 0] dpy_segment, // 七段数码管位扫描信号

    // PS/2 键盘、鼠标接口
    input  wire        ps2_clock,   // PS/2 时钟信号
    input  wire        ps2_data,    // PS/2 数据信号

    // // USB 转 TTL 调试串口
    // output wire        uart_txd,    // 串口发送数据
    // input  wire        uart_rxd,    // 串口接收数据

    // // 4MB SRAM 内存
    // inout  wire [31:0] base_ram_data,   // SRAM 数据
    // output wire [19:0] base_ram_addr,   // SRAM 地址
    // output wire [3: 0] base_ram_be_n,   // SRAM 字节使能，低有效。如果不使用字节使能，请保持为0
    // output wire        base_ram_ce_n,   // SRAM 片选，低有效
    // output wire        base_ram_oe_n,   // SRAM 读使能，低有效
    // output wire        base_ram_we_n,   // SRAM 写使能，低有效

    // HDMI 图像输出
    output wire [7: 0] video_red,   // 红色像素，8位
    output wire [7: 0] video_green, // 绿色像素，8位
    output wire [7: 0] video_blue,  // 蓝色像素，8位
    output wire        video_hsync, // 行同步（水平同步）信号
    output wire        video_vsync, // 场同步（垂直同步）信号
    output wire        video_clk,   // 像素时钟输出
    output wire        video_de,     // 行数据有效信号，用于区分消隐区

    // // RS-232 串口
    // input  wire        rs232_rxd,   // 接收数据
    // output wire        rs232_txd,   // 发送数据
    // input  wire        rs232_cts,   // Clear-To-Send 控制信号
    // output wire        rs232_rts,   // Request-To-Send 控制信号

    // SD 卡（SPI 模式）
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,
    input  wire        sd_miso,
    output wire        sd_cs,       // SPI 片选，低有效
    input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
    input  wire        sd_wp       // 写保护检测，0 表示写保护状态

    // // SDRAM 内存，信号具体含义请参考数据手册
    // output wire [12:0] sdram_addr,
    // output wire [1: 0] sdram_bank,
    // output wire        sdram_cas_n,
    // output wire        sdram_ce_n,
    // output wire        sdram_cke,
    // output wire        sdram_clk,
    // inout wire [15:0] sdram_dq,
    // output wire        sdram_dqmh,
    // output wire        sdram_dqml,
    // output wire        sdram_ras_n,
    // output wire        sdram_we_n,

    // // GMII 以太网接口、MDIO 接口，信号具体含义请参考数据手册
    // output wire        eth_gtx_clk,
    // output wire        eth_rst_n,
    // input  wire        eth_rx_clk,
    // input  wire        eth_rx_dv,
    // input  wire        eth_rx_er,
    // input  wire [7: 0] eth_rxd,
    // output wire        eth_tx_clk,
    // output wire        eth_tx_en,
    // output wire        eth_tx_er,
    // output wire [7: 0] eth_txd,
    // input  wire        eth_col,
    // input  wire        eth_crs,
    // output wire        eth_mdc,
    // inout  wire        eth_mdio
);

/* =========== Demo code begin =========== */
wire clk_in = clk_100m;

// PLL 分频演示，从输入产生不同频率的时钟
wire clk_vga;
ip_pll u_ip_pll(
    .inclk0 (clk_in  ),
    .c0     (clk_vga ),  // 50MHz 像素时钟
    .c1     (clk_ps2 ),  // 25MHz
    .c2     (clk_spi )   // 5MHz SPI SDcard 时钟
);

// SD 卡
reg [31:0] sdc_address;
wire sdc_ready;

reg sdc_read;
wire [7:0] sdc_read_data;
wire sdc_read_valid;

reg sdc_write;
reg [7:0] sdc_write_data;
wire sdc_write_ready;

//sd_controller u_sd_controller (
//    .clk                (clk_spi),
//    .reset              (reset_btn),
//
//    .cs                 (sd_cs),
//    .mosi               (sd_mosi),
//    .miso               (sd_miso),
//    .sclk               (sd_sclk),
//
//    .address            (sdc_address),
//    .ready              (sdc_ready),
//
//    .rd                 (sdc_read),
//    .dout               (sdc_read_data),
//    .byte_available     (sdc_read_valid),
//
//    .wr                 (sdc_write),
//    .din                (sdc_write_data),
//    .ready_for_next_byte(sdc_write_ready)
//);
// Demo
reg [31:0] page_bias;
reg [31:0] current_page;
reg [31:0] target_page;


// 七段数码管扫描演示
reg [31: 0] number;
wire [7:0] scancode;  // PS2
wire scancode_valid;  // PS2
dpy_scan u_dpy_scan (
    .clk     (clk_in      ),
    .number  (number      ),
    .dp      (7'b0        ),
    .digit   (dpy_digit   ),
    .segment (dpy_segment )
);

// 自增计数器，用于数码管演示
reg [1:0] state_reg;
localparam STATE_INIT = 2'd0;
localparam STATE_READ = 2'd1;
localparam STATE_FINISH = 2'd2;

wire [7:0] mem [511:0];
//reg [8:0] write_byte;
reg [31:0] read_byte;

reg [31: 0] counter;

reg [31:0] block_id;
wire execute;

SDCardBlockReader sd_card_block_reader(
    .clk_spi            (clk_spi),
    .reset              (reset_btn),

    .sd_cs              (sd_cs),
    .sd_mosi            (sd_mosi),
    .sd_miso            (sd_miso),
    .sd_sclk            (sd_sclk),

	 .block_id           (block_id),
	 .execute            (execute),
	 .data               (mem),
	 .state_reg          (state_reg)
);

always @(posedge clk_spi or posedge reset_btn) begin
    if (reset_btn) begin
        counter <= 32'b0;
        number[31:8] <= 32'b0;

        read_byte <= 32'd0;
		  
		  block_id <= 32'b0;
		  number[31:24] <= block_id;
		  
    end else begin
		  casez(state_reg)
				STATE_INIT: begin
				  execute = 0;
				  read_byte <= 32'd0;
				end
				STATE_READ: begin
				  execute = 0;
				  read_byte <= 32'd0;
				end
				STATE_FINISH: begin
					 if (read_byte == 32'd512) begin
						  read_byte <= 32'b0;
						  block_id <= block_id + 32'd1;
						  execute = 1;
						  counter <= 32'b0;
					 end else begin
					    counter <= counter + 32'b1;
						 if (counter == 32'd100_000) begin
							counter <= 32'b0;
							number[15:8] <= mem[{read_byte[31:2],2'b0}];
							number[23:16] <= mem[read_byte];
							read_byte <= read_byte + 32'b1;
						 end
					 end
				end
				default: begin
				end
		  endcase
		  number[31:24] <= block_id;
    end
end

wire pause;
wire start;
wire clear;
reg [3:0] file_id;  

KeyBoardController keyboard_controller (
    .clk_in    (clk_in        ),
    .reset     (reset_btn     ),
    .ps2_clock (ps2_clock     ),
    .ps2_data  (ps2_data      ),
	 .pause     (pause         ),
	 .start     (start         ),
	 .clear     (clear         ),
	 .file_id   (number[3:0]   )
);

// LED
assign leds[15:0] = {number[7:0], pause, start, clear};
assign leds[31:16] = ~(dip_sw);

// 图像输出演示，分辨率 800x600@75Hz，像素时钟为 50MHz，显示渐变色彩条
wire [11:0] hdata;  // 当前横坐标
wire [11:0] vdata;  // 当前纵坐标

// 生成彩条数据，分别取坐标低位作为 RGB 值
// 警告：该图像生成方式仅供演示，请勿使用横纵坐标驱动大量逻辑！！
assign video_red = vdata < 200 ? hdata[8:1] : 0;
assign video_green = vdata >= 200 && vdata < 400 ? hdata[8:1] : 0;
assign video_blue = vdata >= 400 ? hdata[8:1] : 0;

assign video_clk = clk_vga;
vga #(12, 800, 856, 976, 1040, 600, 637, 643, 666, 1, 1) vga800x600at75 (
    .clk(clk_vga), 
    .hdata(hdata), //横坐标
    .vdata(vdata), //纵坐标
    .hsync(video_hsync),
    .vsync(video_vsync),
    .data_enable(video_de)
);
/* =========== Demo code end =========== */

endmodule
