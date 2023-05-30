`timescale 1ns / 1ps
// 负责全局的演化
module Round #(
    P_PARAM_M = 5,  // 行 
    P_PARAM_N = 5,  // 列
    WIDTH = 12,     // 宽度
    BLOCK_LEN = 1,  // 一次读取的长度
    READ_COL = 5    // 在RAM中真正的列数
)
(
    input wire clk,                 // 全局时钟
    input wire start,               // 开始游戏的标志
    input wire rst,                 // 全局复位
    input wire global_evo_en,       // 演化标志
    input wire[BLOCK_LEN - 1: 0] round_read_val,   // 演化时有效，代表这个round_read_pos在上一个周期的状态
    output reg wden,                // 演化时有效，代表需要写入
    output reg[2*WIDTH - 1: 0] round_read_pos, // 演化时有效，代表当前演化需要读取的数的位置
    output reg[2*WIDTH - 1: 0] round_write_pos,// 演化时有效，代表演化需要写入的数的位置
    output reg[BLOCK_LEN - 1: 0] live                  // 演化时有效，代表当前位置下一个周期的状态
);

reg prev_global_evo_en;

parameter P_RST = 0;
parameter P_LINE_UP = 1;
parameter P_LINE_MIDDLE = 2;
parameter P_LINE_DOWN = 3;
parameter P_TEMP = 4;
parameter P_CALC = 5;
parameter P_FINISH = 6;
reg [2:0] status;
reg [BLOCK_LEN * 3 - 1: 0] line_status;        // 以行进行统计的状态
reg [2*WIDTH - 1: 0] now_pos;                   // 当前的位置
reg [WIDTH - 1: 0] center_hdata;
reg [WIDTH - 1: 0] center_vdata;

reg prev_start;
reg [3*BLOCK_LEN - 1: 0] last_line_status;
// reg [5:0] last_block_tail; // 记录上一个块的最后两列的状态
reg [BLOCK_LEN - 1: 0] prev_live; // 记录上一个块的全部状态
reg last_prev_live;                 // 上一个块的最后一列的状态
reg [BLOCK_LEN - 1: 0] now_live;  // 记录当前块的全部存活状态
reg [2:0] prev_status;
initial begin
    status = P_RST;
    // line_status = 0;
    center_hdata = 0;
    center_vdata = 0;
    prev_start = 0;
    prev_status = 0;
    prev_global_evo_en = 1;
    last_line_status = 0;
end

Evolution #(BLOCK_LEN) evo(
    .last_line_status(last_line_status),
    .line_status(line_status),
    .now_live(now_live),
    .prev_live_single(last_prev_live)
);

always @ (posedge clk or posedge rst) begin
    prev_start <= start;
    
    if (rst) begin
        status <= P_RST;
        prev_global_evo_en <= 0;
        status <= 0;
        round_read_pos <= 0;
        round_write_pos <= 0;
        wden <= 0;
        line_status <= 0;
        now_pos <= 0;
        last_line_status <= 0;
    end
    else if (prev_start != start && start == 1) begin
        // 从清空状态到重新开始演化，此时需要清空当前状态
        status <= P_RST;
        prev_global_evo_en <= 0;
        status <= 0;
        round_read_pos <= 0;
        round_write_pos <= 0;
        now_pos <= 0;
        wden <= 0;
        line_status <= 0;
        last_line_status <= 0;
    end
    else begin
        prev_status <= status;
        case (prev_status)
            P_LINE_UP : begin
                line_status[BLOCK_LEN - 1: 0] <= round_read_val;
            end 
            P_LINE_MIDDLE : begin
                line_status[2*BLOCK_LEN - 1: BLOCK_LEN] <= round_read_val;
            end 
            P_LINE_DOWN : begin
                line_status[3*BLOCK_LEN - 1: 2*BLOCK_LEN] <= round_read_val; 
            end 
            default: begin
            end
        endcase
        case (status)
            P_RST : begin
                wden <= 0;
                if (prev_global_evo_en != global_evo_en) begin
                    prev_global_evo_en <= global_evo_en;
                    // 此时应当是从第一行开始
                    round_read_pos <= 0;
                    now_pos <= 0;
                    center_vdata <= 0;
                    center_hdata <= 0;
                    line_status <= 0;
                    status <= P_LINE_MIDDLE;
                end
                else begin
                    status <= P_RST;
                end
            end 
            P_LINE_UP : begin
                wden <= 0;
                // 此时读取使能和坐标准备好了
                round_read_pos <= round_read_pos + READ_COL;
                // 切换到下一行
                status <= P_LINE_MIDDLE;
            end
            P_LINE_MIDDLE : begin
                wden <= 0;
                // 此时读取使能和坐标准备好了
                // 切换到下一行
                if (center_vdata != P_PARAM_M - 1) begin
                    round_read_pos <= round_read_pos + READ_COL;
                    status <= P_LINE_DOWN;
                end
                else begin
                    status <= P_TEMP;
                end
            end
            P_LINE_DOWN : begin
                status <= P_TEMP;
            end
            P_TEMP : begin
                // 这里的时候刚读取down的结果到round_read_val，需要再来一个周期放在line_status中
                status <= P_CALC;
            end
            P_CALC : begin
                // 不管哪行的都读取完了
                // 考虑前一块的最后一列，需要当前块的第一列的信息
                // 上一块的live我们还没有写入呢
                // 先考虑是否为第一块，若不是则要写入上一块
                if (center_hdata != 0) begin
                    live[BLOCK_LEN - 2: 0] <= prev_live[BLOCK_LEN - 2: 0];
                    live[BLOCK_LEN - 1] <= last_prev_live;
                    wden <= 1;
                    // 代表写入上一块内容
                    round_write_pos <= now_pos - 1;
                end
                last_line_status <= line_status;
                status <= P_FINISH;
            end
            default : begin
                line_status <= 0;
                if (center_hdata == P_PARAM_N - BLOCK_LEN && center_vdata == P_PARAM_M - 1) begin
                    now_pos <= 0;
                    center_hdata <= 0;
                    center_vdata <= 0;
                    round_read_pos <= 0;
                    // 此时wden仍为1
                    live <= now_live;
                    round_write_pos <= now_pos;
                    status <= P_RST;
                end
                else begin
                    now_pos <= now_pos + 1;
                    prev_live <= now_live;
                    if (center_hdata == P_PARAM_N - BLOCK_LEN) begin
                        // 那么当前读取的就不用再依赖于下一轮的了，也就是正常的
                        live <= now_live;
                        // 直接写入即可
                        center_hdata <= 0;
                        center_vdata <= center_vdata + 1;
                        round_write_pos <= now_pos;
                        round_read_pos <= now_pos + 1 - READ_COL;
                        status <= P_LINE_UP;
                    end
                    else begin
                        wden <= 0;
                        center_hdata <= center_hdata + BLOCK_LEN;
                        if (center_vdata == 0) begin
                            round_read_pos <= now_pos + 1;
                            status <= P_LINE_MIDDLE;
                        end           
                        else begin
                            status <= P_LINE_UP;
                            round_read_pos <= now_pos + 1 - READ_COL;
                        end
                    end
                end
            end
        endcase
    end
end
endmodule