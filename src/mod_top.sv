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
reg [11:0] hdata = 0;  // 当前横坐标
reg [11:0] vdata = 0;  // 当前纵坐标

parameter P_PARAM_N = 32;
parameter P_PARAM_M = 24;
reg [P_PARAM_N * P_PARAM_M - 1: 0] status;
reg [P_PARAM_N * P_PARAM_M - 1: 0] next_status;
// reg [15: 0] pos;    // 在ROM中的位置
// reg [1:0] color = 2;    // pos对应的颜色

reg [2:0] state = 0;    // 初始化状态机
parameter P_STATE_INIT = 0;
parameter P_STATE_READ_ROM_DATA = 1;
parameter P_STATE_EVO_CALC = 2;   // 计算演化的过程
parameter P_STATE_EVO_UPDATE = 3; // 更新完成
parameter P_STATE_WAIT_FOR_EVO = 4; // 演化完成，等待下一次演化
reg [5:0] real_hdata = 0;
reg [5:0] real_vdata = 0;
reg [9:0] pos = 0;      // 在ROM中的位置
// reg [1:0] color = 0;    // ROM当前颜色
reg rden = 0;           // ROM读取使能
// 例化一个ROM模块用于初始化数据
// ROM_1_768 u_rom(
//     .clock(clk_100m),
//     .address(pos),
//     .q(color),
//     .rden()
// );
reg [26:0] cnt = 0;     // 用于计数，用于产生像素时钟
reg clk_evo = 0;            // 用于演化用的时钟
reg finish_evo = 0;     // 新一轮的演化已经完成
always @ (posedge clk_100m) begin
    // 当前没有加入复位
    if (state == P_STATE_INIT) begin
        rden <= 1;
        state <= P_STATE_READ_ROM_DATA;
    end
    else if (state == P_STATE_READ_ROM_DATA) begin
        pos <= real_vdata * P_PARAM_N + real_hdata;
        // status[pos] <= color;
        if(real_hdata[0] == 1) begin
            status[pos] <= 1;
        end
        else begin
            status[pos] <= 0;
        end
        if (real_hdata == P_PARAM_N - 1) begin
            if (real_vdata == P_PARAM_M - 1) begin;
                rden <= 0;
                state <= P_STATE_WAIT_FOR_EVO;
            end
            else begin
                real_vdata <= real_vdata + 1;
                real_hdata <= 0;
            end
        end
        else begin
            real_hdata <= real_hdata + 1;
        end
    end
    else if (state == P_STATE_WAIT_FOR_EVO) begin
        // 等待一个契机，说明即将开始演化计算
        if (cnt == 37499999) begin
            state <= P_STATE_EVO_CALC;
        end
    end
    else if (state == P_STATE_EVO_CALC) begin
        if (finish_evo == 1) begin
            state <= P_STATE_EVO_UPDATE;
        end
    end
    else if (state == P_STATE_EVO_UPDATE) begin
        integer i;
        integer j;
        for (i = 0; i < P_PARAM_M; i = i + 1) begin
            for (j = 0; j < P_PARAM_N; j = j + 1) begin
                status[i * P_PARAM_N + j] <= next_status[i * P_PARAM_N + j];
            end
        end
        state <= P_STATE_WAIT_FOR_EVO;
        // 更新完成，等待下一次演化
    end
end

always @ (posedge clk_vga) begin
    if (cnt == 37499999) begin
        clk_evo <= ~clk_evo;
        cnt <= 0;
    end
    else begin
        cnt <= cnt + 1;
    end
end

Evolution #(P_PARAM_N, P_PARAM_M) evo(
    .clk(clk_evo),
    .prev(status),
    .next(next_status),
    .finish_evo(finish_evo)
);

assign video_clk = clk_vga;
vga #(12, 1024, 1048, 1184, 1328, 768, 771, 777, 806, 1, 1, P_PARAM_N, P_PARAM_M) vag1024x768at70 (
    .clk(clk_vga), 
    .status(status),// 全局像素信息
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
