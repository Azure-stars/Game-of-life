`timescale 1ns / 1ps
// 负责全局的演化
module Round #(
    P_PARAM_M = 5,  // 行 
    P_PARAM_N = 5,  // 列
    WIDTH = 12,     // 每一行显示的像素的个数
    BLOCK_LEN = 1,  // 每块包含的像素数目
    READ_COL = 5    // 每一行的块数，在RAM中逐块存储像素信息
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

parameter P_RST = 0;        // 复位周期，此时应当将所有的状态清空
parameter P_LINE_UP = 1;    // 读取当前计算点所在的行的上一行
parameter P_LINE_MIDDLE = 2;// 读取当前计算点所在的行
parameter P_LINE_DOWN = 3;  // 读取当前计算点所在的行的下一行      
parameter P_TEMP = 4;       // 中转周期，用于将RAM读取的信息存储在寄存器中
parameter P_CALC = 5;       // 计算周期，在这个周期开始时，下一轮的演化结果已经出来了，要将其写入RAM
parameter P_FINISH = 6;     // 结束周期，判断是继续，还是完成了演化
reg [2:0] status;           // 状态机的状态
reg [BLOCK_LEN * 3 - 1: 0] line_status;         // 以行进行统计的状态
reg [2*WIDTH - 1: 0] now_pos;                   // 当前演化的位置
reg [WIDTH - 1: 0] center_hdata;                // 当前演化位置的横坐标
reg [WIDTH - 1: 0] center_vdata;                // 当前演化位置的纵坐标

reg prev_start;                                 // 存储是否需要重新开始，若是从暂停状态到演化状态，则需要重新开始
reg [3*BLOCK_LEN - 1: 0] last_line_status;      // 记录当前演化位置的上一个块的上中下三行的状态，用于计算当前块的第一列
reg [BLOCK_LEN - 1: 0] prev_live;               // 记录上一个块的全部状态
reg last_prev_live;                             // 上一个块的最后一列的状态
reg [BLOCK_LEN - 1: 0] now_live;                // 记录当前块的全部存活状态
reg [2:0] prev_status;                          // 记录上一个周期的位置，因为RAM读取存在时延，因此某一行的数据要到下一个周期才能读取并且存进去
initial begin
    status = P_RST;
    center_hdata = 0;
    center_vdata = 0;
    prev_start = 0;
    prev_status = 0;
    prev_global_evo_en = 1;
    last_line_status = 0;
end

// 计算当前块的第一列与上一个块的最后一列
// 组合逻辑
Evolution #(BLOCK_LEN) evo(
    .last_line_status(last_line_status),
    .line_status(line_status),
    .now_live(now_live),
    .prev_live_single(last_prev_live)
);

always @ (posedge clk or posedge rst) begin
    prev_start <= start;
    if (rst) begin
        // 复位状态
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
        // 将上一个周期得到的结果写入对应的位置
        // 因为读取存在时延，所以要存储上一个周期的状态
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
                // 演化准备开始，此时应当等待时钟沿变化信号
                wden <= 0;
                if (prev_global_evo_en != global_evo_en) begin
                    // 时钟沿变化，代表一个新的演化周期开始了
                    prev_global_evo_en <= global_evo_en;
                    // 此时应当是从第一行开始
                    round_read_pos <= 0;
                    now_pos <= 0;
                    center_vdata <= 0;
                    center_hdata <= 0;
                    line_status <= 0;
                    // 第一行上面没有空余行，因此直接从当前点所在行开始读取
                    status <= P_LINE_MIDDLE;
                end
                else begin
                    status <= P_RST;
                end
            end 
            P_LINE_UP : begin
                // 读取当前演化点上面的一行
                wden <= 0;
                // 此时读取使能和坐标准备好了
                round_read_pos <= round_read_pos + READ_COL;
                // 切换到下一行
                status <= P_LINE_MIDDLE;
            end
            P_LINE_MIDDLE : begin
                // 读取当前演化点所在的行
                wden <= 0;
                if (center_vdata != P_PARAM_M - 1) begin
                    // 若是最后一行，则下面没有空余行，直接开始计算
                    round_read_pos <= round_read_pos + READ_COL;
                    status <= P_LINE_DOWN;
                end
                else 
                begin
                    // 否则准备读取当前演化点下面的哪一行
                    status <= P_TEMP;
                end
            end
            P_LINE_DOWN : begin
                // 读取当前演化点所在的下一行
                status <= P_TEMP;
            end
            P_TEMP : begin
                // 这里的时候刚读取最后一个需要读取的line(down或者middle)的结果到round_read_val，需要再来一个周期放在line_status中
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
                status <= P_FINISH;
            end
            default : begin
                line_status <= 0;
                // 此时读取已经结束了，本块在本周期的大部分生命状态已经存储在live中
                
                if (center_hdata == P_PARAM_N - BLOCK_LEN && center_vdata == P_PARAM_M - 1) begin
                    // 此时是最后一块，没有下一块，所以可以写入本块信息
                    // 同时最后一块应当停止运行，即返回P_RST状态
                    now_pos <= 0;
                    center_hdata <= 0;
                    center_vdata <= 0;
                    round_read_pos <= 0;
                    // 此时wden仍为1
                    live <= now_live;
                    round_write_pos <= now_pos;
                    last_line_status <= 0;
                    status <= P_RST;
                end
                else begin
                    now_pos <= now_pos + 1;
                    prev_live <= now_live;
                    if (center_hdata == P_PARAM_N - BLOCK_LEN) begin
                        last_line_status <= 0;  // 这里的清空是必要的，否则会影响下一行第0列的情况
                        // 当前块是一行的最后一块，就不用再依赖下一个块了，可以直接写入
                        live <= now_live;
                        // 直接写入即可
                        center_hdata <= 0;
                        center_vdata <= center_vdata + 1;
                        round_write_pos <= now_pos;
                        round_read_pos <= now_pos + 1 - READ_COL;
                        status <= P_LINE_UP;
                    end
                    else begin
                        // 本块的最后一列的状态还需要下一块的第一列，因此不能直接写入，应当等到下一个块读取完毕进行计算之后，再写入本块的状态
                        last_line_status <= line_status;
                        wden <= 0;
                        center_hdata <= center_hdata + BLOCK_LEN;
                        if (center_vdata == 0) begin
                            // 下一个块是第一行的，那么没有需要读取的上空闲行
                            round_read_pos <= now_pos + 1;
                            status <= P_LINE_MIDDLE;
                        end           
                        else begin
                            status <= P_LINE_UP;
                            // 否则从上空闲行开始读取
                            round_read_pos <= now_pos + 1 - READ_COL;
                        end
                    end
                end
            end
        endcase
    end
end
endmodule