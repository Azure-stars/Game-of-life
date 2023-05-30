`timescale 1ns / 1ps
module Evolution
#(BLOCK_LEN = 1)
// 默认大小100 * 100
(
  input wire [3 * BLOCK_LEN - 1: 0] last_line_status,
  input wire [3 * BLOCK_LEN - 1: 0] line_status,
  output reg [BLOCK_LEN - 1: 0] now_live,      // 是否存活
  output reg prev_live_single  // 上一块的存活状态
);

always_comb begin
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
        if (line_status[j + k * BLOCK_LEN - 1] == 1) begin
          live_num_2 = live_num_2 + 1;
        end
      end
      else begin
        if (last_line_status[(k + 1) * BLOCK_LEN - 1] == 1) begin
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
