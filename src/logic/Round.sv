`timescale 1ns / 1ps
// 负责全局的演化
module Round #(
    P_PARAM_M = 5,  // 行 
    P_PARAM_N = 5,  // 列
    WIDTH = 12     // 宽度
)
(
    input wire clk,                 // 全局时钟
    input wire global_evo_en,       // 演化标志，当上升沿到来时进行演化
    input wire prev_status,         // 演化时有效，代表这个round_read_pos在上一个周期的状态
    output reg rden,                // 演化时有效，代表需要读取
    output reg wden,                // 演化时有效，代表需要写入
    output reg[2*WIDTH - 1: 0] round_read_pos, // 演化时有效，代表当前演化需要读取的数的位置
    output reg[2*WIDTH - 1: 0] round_write_pos,// 演化时有效，代表演化需要写入的数的位置
    output reg live,                // 演化时有效，代表当前位置下一个周期的状态
    output reg copy_rden,           // 拷贝时有效，代表拷贝来源读使能
    output reg copy_wden            // 拷贝时有效，代表拷贝目的写使能
);


reg [8:0] status;        
// 当前位置及其周围的状态，若当前坐标为(i,j),status[0] = (i,j), status[1] = (i,j+1), status[2] = (i+1, j+1), 即顺时针旋转
parameter P_INIT = 0;
parameter P_READ_STATE_0 = 1;  // 当read_state到达这个状态时，代表已经完成了对应位置的读取
parameter P_READ_STATE_1 = 2;
parameter P_READ_STATE_2 = 3;
parameter P_READ_STATE_3 = 4;
parameter P_READ_STATE_4 = 5;
parameter P_READ_STATE_5 = 6;
parameter P_READ_STATE_6 = 7;
parameter P_READ_STATE_7 = 8;
parameter P_READ_STATE_8 = 9;
parameter P_WRITE = 10;
parameter P_COPY = 11;
parameter P_FINISH = 12;
reg prev_global_evo_en;      // 上一个时钟的全局演化使能，利用这个将电平信号转化为时钟信号
// reg evo_en;              // 局部开始演化的使能
reg[3:0] read_state;     // 用于RAM读取的状态
reg[3:0] end_state;      // 结束读取位置，不包括自己
reg[WIDTH - 1: 0] center_hdata;     // 当前输出的real_hdata坐标
reg[WIDTH - 1: 0] center_vdata;     // 当前输出的real_vdata坐标
initial begin
    prev_global_evo_en = 0;
    status = 0;
    // evo_en = 0;
    read_state = P_INIT;
    end_state = 0;
    center_hdata = 0;
    center_vdata = 0;
    round_read_pos = 0;
    round_write_pos = 0;
    copy_rden = 0;
    copy_wden = 0;
    rden = 0;
    wden = 0;
    live = 0;
end


Evolution evo (
    .status(status),
    .live(live)
);

// 转化模块，将global_evo_en的电平信号转化为上升沿信号
always @ (posedge clk) begin
    prev_global_evo_en <= global_evo_en;
end


// 读取模块
always @ (posedge clk) begin
    if (read_state <= P_READ_STATE_8 && read_state >= P_READ_STATE_0) begin
        status[read_state - 1] <= prev_status; 
    end
    if (read_state == P_INIT) begin
        if (prev_global_evo_en != global_evo_en) begin
            // global_evo_en变化到来
            // 初始化读取中心位置的值 
            // 此时的round_read_pos应当为0
            rden <= 1;  // 进行读取
            read_state <= P_READ_STATE_0;
        end
        else begin
            read_state <= P_INIT;
        end
    end
    else if (read_state == P_READ_STATE_0) begin
        // 根据当前位置决定下一个读取位置与中止读取位置
        if (center_hdata == 0) begin
            // 第0列
            if (center_vdata == 0) begin
                // 第0行
                round_read_pos <= round_read_pos + 1;
                read_state <= P_READ_STATE_1;
                end_state <= P_READ_STATE_3;
            end
            else if (center_vdata == P_PARAM_M - 1) begin
                // 最后一行
                round_read_pos <= round_read_pos - P_PARAM_N;
                read_state <= P_READ_STATE_7;
                end_state <= P_READ_STATE_1;
            end
            else begin
                round_read_pos <= round_read_pos - P_PARAM_N;
                read_state <= P_READ_STATE_7;
                end_state <= P_READ_STATE_3;
            end
        end
        else if (center_hdata == P_PARAM_N - 1) begin
            if (center_vdata == 0) begin
                round_read_pos <= round_read_pos + P_PARAM_N;
                read_state <= P_READ_STATE_3;
                end_state <= P_READ_STATE_5;
            end
            else if (center_vdata == P_PARAM_M - 1) begin
                round_read_pos <= round_read_pos - 1;
                read_state <= P_READ_STATE_5;
                end_state <= P_READ_STATE_7;
            end
            else begin
                round_read_pos <= round_read_pos + P_PARAM_N;
                read_state <= P_READ_STATE_3;
                end_state <= P_READ_STATE_7;
            end
        end
        else begin
            if (center_vdata == 0) begin
                round_read_pos <= round_read_pos + 1;
                read_state <= P_READ_STATE_1;
                end_state <= P_READ_STATE_5;
            end
            else if (center_vdata == P_PARAM_M - 1) begin
                round_read_pos <= round_read_pos - 1;
                read_state <= P_READ_STATE_5;
                end_state <= P_READ_STATE_1;
            end
            else begin
                round_read_pos <= round_read_pos + 1;
                read_state <= P_READ_STATE_1;
                end_state <= P_READ_STATE_8;
            end
        end 
        
    end 
    else if (read_state == P_READ_STATE_1 || read_state == P_READ_STATE_8) begin
        if (read_state == end_state) begin
            // 读取完毕
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
            // 是否演化需要进行考虑，如果当前是global_evo_en上升沿到来的第一个读取周期，那么要进行演化，否则保持不变
            // evo_en <= 1;
            read_state <= P_WRITE;     // 待读取完这个位置之后，读取完毕
        end
        else begin
            // 否则更新读取位置
            if (read_state == P_READ_STATE_1) begin
                read_state <= P_READ_STATE_2;
            end
            else begin
                read_state <= P_READ_STATE_1;
            end
            round_read_pos <= round_read_pos + P_PARAM_N;
            // 由于保证了可以读取到P_READ_STATE_1,因此不会越界
        end
    end
    else if (read_state == P_READ_STATE_2 || read_state == P_READ_STATE_3) begin
        if (read_state == end_state) begin
            // 读取完毕
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
            // evo_en <= 1;
            read_state <= P_WRITE;     // 待读取完这个位置之后，读取完毕
        end
        else begin
            // 否则更新读取位置
            if (read_state == P_READ_STATE_2) begin
                read_state <= P_READ_STATE_3;
            end
            else begin
                read_state <= P_READ_STATE_4;
            end
            round_read_pos <= round_read_pos - 1;
            // 由于保证了可以读取到P_READ_STATE_1,因此不会越界
        end
    end
    else if (read_state == P_READ_STATE_4 || read_state == P_READ_STATE_5) begin
        if (read_state == end_state) begin
            // 读取完毕
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
            // evo_en <= 1;
            read_state <= P_WRITE;     // 待读取完这个位置之后，读取完毕
        end
        else begin
            if (read_state == P_READ_STATE_4) begin
                read_state <= P_READ_STATE_5;
            end
            else begin
                read_state <= P_READ_STATE_6;
            end
            // 否则更新读取位置
            round_read_pos <= round_read_pos - P_PARAM_N;
            // 由于保证了可以读取到P_READ_STATE_1,因此不会越界
        end
    end
    else if (read_state == P_READ_STATE_6 || read_state == P_READ_STATE_7) begin
        if (read_state == end_state) begin
            // 读取完毕
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
            // evo_en <= 1;
            read_state <= P_WRITE;     // 待读取完这个位置之后，读取完毕
        end
        else begin
            // 否则更新读取位置
            if (read_state == P_READ_STATE_6) begin
                read_state <= P_READ_STATE_7;
            end
            else begin
                read_state <= P_READ_STATE_8;
            end
            round_read_pos <= round_read_pos + 1;
            // 由于保证了可以读取到P_READ_STATE_1,因此不会越界
        end
    end  
    else if (read_state == P_WRITE) begin
        // 到达这个状态时已经写入完毕
        // 清空当前的状态，为下一轮迭代做准备
        wden <= 0;
        // evo_en <= 0;
        if (center_hdata == P_PARAM_N - 1) begin
            if (center_vdata == P_PARAM_M - 1) begin
                center_vdata <= 0;
                copy_rden <= 1;
                copy_wden <= 1;
                round_read_pos <= 0;
                round_write_pos <= 0;
                read_state <= P_COPY;
            end
            else begin
                round_read_pos <= round_read_pos + 1;
                round_write_pos <= round_write_pos + 1;
                center_vdata <= center_vdata + 1;
                rden <= 1;
                read_state <= P_READ_STATE_0;
            end
            center_hdata <= 0;
        end
        else begin
            round_read_pos <= round_read_pos + 1;
            round_write_pos <= round_write_pos + 1;
            center_hdata <= center_hdata + 1;
            rden <= 1;
            read_state <= P_READ_STATE_0;
        end
        status[8:1] <= 0;
    end
    else if(read_state == P_COPY) begin
        round_read_pos <= round_write_pos;
        if (round_write_pos != P_PARAM_N * P_PARAM_M - 1) begin
            // 注意：此时copy_wround_read_pos应当比copy_rround_read_pos晚一个周期
            round_write_pos <= + 1;
            read_state <= P_COPY;
        end
        else begin
            read_state <= P_FINISH;
        end
    end
    else begin
        // P_FINISH
        copy_rden <= 0;
        copy_wden <= 0;
        round_read_pos <= 0;
        round_write_pos <= 0;
        read_state <= P_INIT;
    end
end


endmodule