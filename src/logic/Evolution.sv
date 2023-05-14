`timescale 1ns / 1ps
module Evolution
// 默认大小100 * 100
(
  input wire [8:0] status, // 自身与周围块的状态
  output reg live      // 是否存活
);

integer i;
integer liveNum;
reg next_live = 0;
always_comb begin
  liveNum = 0;
  for (i = 1; i < 9; i = i + 1) begin
    if (status[i] == 1) begin
      liveNum = liveNum + 1;
    end
  end
  if (status[0] == 0 && liveNum == 3) begin
    next_live = 1;
  end
  else if (status[0] == 1 && (liveNum == 2 || liveNum == 3)) begin
    next_live = 1;
  end
  else begin
    next_live = 0;
  end
end
assign live = 1;
endmodule
