module Evolution #(
    parameter P_PARAM_N = 5,    // 列
    parameter P_PARAM_M = 5     // 行
)
// 默认大小100 * 100
(
    input  wire clk,
    input  reg [P_PARAM_N * P_PARAM_M - 1:0] prev,
    output reg [P_PARAM_N * P_PARAM_M - 1:0] next,
    output reg finish_evo   // 是否完成了演化
);
  integer liveNum = 0;
  integer i = 0;
  integer j = 0;
  always @ (posedge clk) begin
    finish_evo = 0;     //应当用阻塞赋值
    for (i = 0; i < P_PARAM_M; i = i + 1) begin
      for (j = 0; j < P_PARAM_N; j = j + 1) begin
        liveNum = 0;
        if (j > 0) begin
          if (i > 0) begin
            if (prev[(i - 1) * P_PARAM_N + j - 1]) begin
              liveNum = liveNum + 1;
            end
          end
          if (prev[i * P_PARAM_N + j - 1] != 0) begin
            liveNum = liveNum + 1;
          end
          if (i < P_PARAM_M - 1) begin
            if (prev[(i + 1) * P_PARAM_N + j - 1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
        end
        if (i > 0) begin
          if (prev[(i - 1) * P_PARAM_N + j] != 0) begin
            liveNum = liveNum + 1;
          end
        end
        if (i < P_PARAM_M - 1) begin
          if (prev[(i + 1) * P_PARAM_N + j] != 0) begin
            liveNum = liveNum + 1;
          end
        end
        if (j < P_PARAM_N - 1) begin
          if (i > 0) begin
            if (prev[(i - 1) * P_PARAM_N + j + 1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
          if (i < P_PARAM_M - 1) begin
            if (prev[(i + 1) * P_PARAM_N + j + 1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
          if (prev[i * P_PARAM_N + j + 1] != 0) begin
            liveNum = liveNum + 1;
          end
        end
        if (prev[i * P_PARAM_N + j] == 0 && liveNum == 3) begin
          next[i * P_PARAM_N + j] <= 1;
        end else if (prev[i * P_PARAM_N + j] == 1 && (liveNum == 2 || liveNum == 3)) begin
          next[i * P_PARAM_N + j] <= 1;
        end else begin
          next[i * P_PARAM_N + j] <= 0;
        end
        // next[i * P_PARAM_N + j] <= prev[i * P_PARAM_N + j];
      end
    end
    finish_evo <= 1;    // 标志已经完成了演化
  end
  

endmodule
