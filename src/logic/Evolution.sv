`timescale 1ns / 1ps
module Evolution
#(BLOCK_LEN = 1)
// 默认大小100 * 100
(
  input wire [5:0] last_block_tail,
  input wire [3 * BLOCK_LEN - 1: 0] line_status,
  output reg [BLOCK_LEN - 1: 0] now_live,      // 是否存活
  output reg prev_live_single  // 上一块的存活状态
);

always_comb begin
  integer i;
  automatic integer live_num_1 = 0;
  for (i = 0; i < 6; i = i + 1) begin
    if (i != 4 && last_block_tail[i] === 1) begin
      live_num_1 = live_num_1 + 1;
    end
  end
  if (line_status[0] == 1) begin
    live_num_1 = live_num_1 + 1;
  end
  if (line_status[BLOCK_LEN] == 1) begin
    live_num_1 = live_num_1 + 1;
  end
  if (line_status[2 * BLOCK_LEN] == 1) begin
    live_num_1 = live_num_1 + 1;
  end
  if (live_num_1 == 3) begin
    prev_live_single = 1;
  end
  else if (last_block_tail[4] == 1 && live_num_1 == 2) begin
    prev_live_single = 1;
  end
  else begin
    prev_live_single = 0;
  end
end

always_comb begin
  integer j;
  integer k;
  automatic integer live_num_2 = 0;
  for (j = 1; j <= BLOCK_LEN - 1; j = j + 1) begin
    live_num_2 = 0;
    for (k = 0; k < 3; k = k + 1) begin
      if (k != 1 && line_status[j + k * BLOCK_LEN] == 1) begin
        // 注意不算自己
        live_num_2 = live_num_2 + 1;
      end
      if (j != BLOCK_LEN - 1) begin
        if (line_status[j + k * BLOCK_LEN + 1] == 1) begin
          live_num_2 = live_num_2 + 1;
        end
      end
      if (line_status[j + k * BLOCK_LEN - 1] == 1) begin
        live_num_2 = live_num_2 + 1;
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

always_comb begin
  integer j;
  automatic integer live_num = 0;
  for(j = 3; j < 6; j = j + 1) begin
    if (last_block_tail[j] == 1) begin
      live_num = live_num + 1;
    end
  end
  for (j = 0; j < 3; j = j + 1) begin
    if (j != 1 && line_status[j * BLOCK_LEN] == 1) begin
      live_num = live_num + 1;
    end
    if (line_status[j * BLOCK_LEN + 1] == 1) begin
      live_num = live_num + 1;
    end
  end
  if (live_num == 3) begin
    now_live[0] = 1;
  end
  else if (live_num == 2 && line_status[BLOCK_LEN] == 1) begin
    now_live[0] = 1;
  end
  else begin
    now_live[0] = 0;
  end
end

endmodule
