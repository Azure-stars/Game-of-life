`timescale 1ns / 1ps
module Evolution
#(BLOCK_LEN = 1)
// 默认大小100 * 100
(
  input wire [3 * BLOCK_LEN - 1: 0] last_line_status,   // 上一块的状态
  input wire [3 * BLOCK_LEN - 1: 0] line_status,        // 自身的块的状态
  output reg [BLOCK_LEN - 1: 0] now_live,               // 当前读取块的下一个周期的状态
  output reg prev_live_single                           // 上一块的最后一个状态
);

always_comb begin
  // 计算上一块的最后一个状态
  // 大致思路即为读取周围的八个状态进行计算即可
  // 注意别把自己算进去了
  automatic integer live_num_1 = 0;
  for (int i = 1; i <= 3; i = i + 1) begin
    if (i != 2 && last_line_status[i * BLOCK_LEN - 1] == 1) begin
      live_num_1 = live_num_1 + 1;
    end
    if (last_line_status[i * BLOCK_LEN - 2] == 1) begin
      live_num_1 = live_num_1 + 1;
    end
    if (line_status[(i - 1) * BLOCK_LEN] == 1) begin
      live_num_1 = live_num_1 + 1;
    end
  end
  if (live_num_1 == 3) begin
    prev_live_single = 1;
  end
  else if (last_line_status[2 * BLOCK_LEN - 1] == 1 && live_num_1 == 2) begin
    prev_live_single = 1;
  end
  else begin
    prev_live_single = 0;
  end
end

always_comb begin
  // 计算当前块的下一个周期的状态
    // 大致思路即为读取周围的八个状态进行计算即可
  // 注意别把自己算进去了
  automatic integer live_num_2 = 0;
  for (int j = 0; j <= BLOCK_LEN - 1; j = j + 1) begin
    live_num_2 = 0;
    for (int k = 0; k < 3; k = k + 1) begin
      if (k != 1 && line_status[j + k * BLOCK_LEN] == 1) begin
        // 注意不算自己
        live_num_2 = live_num_2 + 1;
      end
      if (j != BLOCK_LEN - 1) begin
        if (line_status[j + k * BLOCK_LEN + 1] == 1) begin
          live_num_2 = live_num_2 + 1;
        end
      end
      if (j != 0) begin
        // 如果不是当前块的第一列，那么读取的内容都在本块内
        if (line_status[j + k * BLOCK_LEN - 1] == 1) begin
          live_num_2 = live_num_2 + 1;
        end
      end
      else begin
        // 否则需要借助上一个块的状态进行计算
        if (last_line_status[k * BLOCK_LEN - 1 + BLOCK_LEN] == 1) begin
          live_num_2 = live_num_2 + 1;
        end
      end
    end
    if (live_num_2 == 3) begin
      now_live[j] = 1;
    end
    else if (live_num_2 == 2 && line_status[j + BLOCK_LEN] == 1) begin
      now_live[j] = 1;
    end
    else begin
      now_live[j] = 0;
    end
  end  
end

endmodule
