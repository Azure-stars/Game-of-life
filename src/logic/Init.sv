/// 用于从初始化RAM读取内容转移到其他四个RAM中

module Init #(
    P_PARAM_M = 5,                              // 行 
    P_PARAM_N = 5,                              // 列
    WIDTH = 12,                                 // 每一行显示的像素的个数
    BLOCK_LEN = 1,                              // 每块包含的像素数目
    READ_COL = 5                                // 每一行的块数，在RAM中逐块存储像素信息
)(
    input wire clk,                             // 全局时钟
    input wire start,                           // 是否开始新的一轮初始化，上升沿有效
    input wire[BLOCK_LEN - 1: 0] read_val,      // 从RAM读取的数据
    output reg [2*WIDTH-1:0] read_addr,         // 读取的地址
    output reg [2*WIDTH-1:0] write_addr,        // 写入的地址
    output reg write_en,                        // 写入使能
    output reg[BLOCK_LEN - 1: 0] write_val,     // 写入的数据，就是上次从初始化内存中读入的数据
    output reg finish                           // 是否完成了写入
);
    reg [2:0] state;
    parameter STATE_INIT = 0;                   // 初始化状态
    parameter STATE_START = 1;                  // 开始状态
    parameter STATE_READ = 2;                   // 读取状态
    parameter STATE_WRITE = 3;                  // 写入状态
    parameter STATE_FINISH = 4;                 // 完成初始化
    reg prev_start;                             // start 在上一个时钟周期的值，与 start 一起判断是否开始新的一轮初始化
    initial begin
        prev_start = 0;
        state = 0;
    end
    always @ (posedge clk) begin
        prev_start <= start;
        case (state)
            STATE_INIT : begin
                if (prev_start != start) begin
                    state <= STATE_START;
                    read_addr <= 0;
                    write_addr <= 0;
                    write_val <= 0;
                    finish <= 0;
                end
                else begin
                    state <= STATE_INIT;
                end
            end 
            STATE_START : begin
                // 这个地方把即将读取的地址和使能都准备好了，但是还没有读取
                state <= STATE_READ;
            end
            STATE_READ : begin
                // 这个地方已经成功读取到了值
                write_val <= read_val;
                write_en <= 1;
                state <= STATE_WRITE;
            end
            STATE_WRITE : begin
                // 这个地方已经把写入的值准备好了
                state <= STATE_FINISH;
            end
            STATE_FINISH : begin
                // 成功写入了值
                write_en <= 0;
                if (write_addr != (P_PARAM_M * READ_COL - 1)) begin
                    // 写入还未结束，继续写入
                    state <= STATE_START;
                    write_addr <= write_addr + 1;
                    read_addr <= read_addr + 1;
                end
                else begin
                    // 直接复位
                    state <= STATE_INIT;
                    finish <= 1;
                end
            end
            default: begin
            end
        endcase
    end
endmodule