`timescale 1ns / 1ps
// 负责全局的演化
module Round #(
    P_PARAM_M = 5,  // 行 
    P_PARAM_N = 5,  // 列
    WIDTH = 12     // 宽度
)
(
    input wire clk,                 // 全局时钟
    input wire global_evo_en,       // 演化标志
    input wire prev_status,         // 演化时有效，代表这个round_read_pos在上一个周期的状态
    output reg rden,                // 演化时有效，代表需要读取
    output reg wden,                // 演化时有效，代表需要写入
    output reg[2*WIDTH - 1: 0] round_read_pos, // 演化时有效，代表当前演化需要读取的数的位置
    output reg[2*WIDTH - 1: 0] round_write_pos,// 演化时有效，代表演化需要写入的数的位置
    output reg live                 // 演化时有效，代表当前位置下一个周期的状态
);

reg prev_global_evo_en = 1;
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
parameter P_CALC = 10;
parameter P_WRITE = 11;
parameter P_FINISH = 12;
reg[3:0] last_read_state;       // 上一次读取到的位置
reg[3:0] read_state;     // 用于RAM读取的状态
reg[3:0] end_state;      // 结束读取位置，不包括自己
reg[WIDTH - 1: 0] center_hdata;     // 当前输出的real_hdata坐标
reg[WIDTH - 1: 0] center_vdata;     // 当前输出的real_vdata坐标
reg[30:0] evo_cnt;              // 1Hz时钟的计数器
initial begin
    prev_global_evo_en = 1;
    status = 0;
    read_state = P_INIT;
    end_state = 0;
    center_hdata = 0;
    center_vdata = 0;
    round_read_pos = 0;
    round_write_pos = 0;
    rden = 0;
    wden = 0;
    // live = 0;
    evo_cnt = 0;
    last_read_state = 0;
end


// Evolution evo (
//     .status(status),
//     .live(live)
// );

// assign live = prev_status;

always @ (posedge clk) begin
    if (evo_cnt == 49999999) begin
        evo_cnt <= 0;
    end else begin
        evo_cnt <= evo_cnt + 1;
    end
end

// 读取模块
always @ (posedge clk) begin
    if (read_state >= P_READ_STATE_0 && read_state <= P_READ_STATE_8) begin
        last_read_state <= read_state - 1;
        // status[read_state - 1] <= prev_status;
    end
    if (read_state <= P_CALC && read_state >= P_READ_STATE_1) begin
        status[last_read_state] <= prev_status; 
    end
    if (read_state == P_INIT) begin
        if (prev_global_evo_en != global_evo_en) begin
            // 初始化读取中心位置的值 
            // 此时的round_read_pos应当为0
            prev_global_evo_en <= global_evo_en;
            round_read_pos <= 1;
            rden <= 1;  // 进行读取
            read_state <= P_READ_STATE_0;
        end
        else
        begin
            read_state <= P_INIT;
        end
    end
    else if (read_state == P_READ_STATE_0) begin
        // 根据当前位置决定下一个读取位置与中止读取位置
        // 根据时序因素，我们在进入到P_READ_STATE_0还没有读取到
        // 会在下一个时钟到来才会读到
        // round_read_pos = round_write_pos;
        read_state <= P_CALC;
        // if (center_hdata == 0) begin
        //     // 第0列
        //     if (center_vdata == 0) begin
        //         // 第0行
        //         round_read_pos <= round_read_pos + 1;
        //         read_state <= P_READ_STATE_1;
        //         end_state <= P_READ_STATE_3;
        //     end
        //     else if (center_vdata == P_PARAM_M - 1) begin
        //         // 最后一行
        //         round_read_pos <= round_read_pos - P_PARAM_N;
        //         read_state <= P_READ_STATE_7;
        //         end_state <= P_READ_STATE_1;
        //     end
        //     else begin
        //         round_read_pos <= round_read_pos - P_PARAM_N;
        //         read_state <= P_READ_STATE_7;
        //         end_state <= P_READ_STATE_3;
        //     end
        // end
        // else if (center_hdata == P_PARAM_N - 1) begin
        //     if (center_vdata == 0) begin
        //         round_read_pos <= round_read_pos + P_PARAM_N;
        //         read_state <= P_READ_STATE_3;
        //         end_state <= P_READ_STATE_5;
        //     end
        //     else if (center_vdata == P_PARAM_M - 1) begin
        //         round_read_pos <= round_read_pos - 1;
        //         read_state <= P_READ_STATE_5;
        //         end_state <= P_READ_STATE_7;
        //     end
        //     else begin
        //         round_read_pos <= round_read_pos + P_PARAM_N;
        //         read_state <= P_READ_STATE_3;
        //         end_state <= P_READ_STATE_7;
        //     end
        // end
        // else begin
        //     if (center_vdata == 0) begin
        //         round_read_pos <= round_read_pos + 1;
        //         read_state <= P_READ_STATE_1;
        //         end_state <= P_READ_STATE_5;
        //     end
        //     else if (center_vdata == P_PARAM_M - 1) begin
        //         round_read_pos <= round_read_pos - 1;
        //         read_state <= P_READ_STATE_5;
        //         end_state <= P_READ_STATE_1;
        //     end
        //     else begin
        //         round_read_pos <= round_read_pos + 1;
        //         read_state <= P_READ_STATE_1;
        //         end_state <= P_READ_STATE_8;
        //     end
        // end 
    end 
    else if (read_state == P_READ_STATE_1 || read_state == P_READ_STATE_8) begin
        if (read_state == end_state) begin
            // 读取完毕
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
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
            rden <= 0;
            // 准备写入当前的结果到RAM2
            wden <= 1;
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
    else if (read_state == P_CALC) begin
        // 到达这个状态时，所有读取完毕
        wden <= 1; 
        rden <= 0;

        round_read_pos <= round_write_pos + 1;
        live <= prev_status;
        read_state <= P_WRITE;
    end
    else if (read_state == P_WRITE) begin
        wden <= 0;
        read_state <= P_FINISH;
    end
    else begin
        // P_FINISH
        if (center_hdata == P_PARAM_N - 1) begin
            if (center_vdata == 1) begin
                center_vdata <= 0;
                round_read_pos <= 0;
                round_write_pos <= 0;
                read_state <= P_INIT;
            end
            else begin
                // 此时的read_pos并不在最开始的中心，需要将其和read_pos进行同步
                round_write_pos <= round_read_pos;
                center_vdata <= center_vdata + 1;
                rden <= 1;
                read_state <= P_READ_STATE_0;
            end
            center_hdata <= 0;
        end
        else begin
            round_write_pos <= round_read_pos;
            center_hdata <= center_hdata + 1;
            rden <= 1;
            read_state <= P_READ_STATE_0;
        end
        // 下一个时钟周期才会清零，不会影响当前的周期
        status[8:1] <= 0;
    end
end

endmodule