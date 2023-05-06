module Evolution #(
    parameter P_PARAM_N = 5
)
// 默认大小100 * 100
(
    input  reg [P_PARAM_N - 1:0][P_PARAM_N - 1:0] prev,
    output reg [P_PARAM_N - 1:0][P_PARAM_N - 1:0] next
);
  integer liveNum = 0;
  integer i = 0;
  integer j = 0;

  always_comb begin
    for (i = 0; i < P_PARAM_N; i = i + 1) begin
      for (j = 0; j < P_PARAM_N; j = j + 1) begin
        liveNum = 0;
        if (j > 0) begin
          if (i > 0) begin
            if (prev[i-1][j-1]) begin
              liveNum = liveNum + 1;
            end
          end
          if (prev[i][j-1] != 0) begin
            liveNum = liveNum + 1;
          end
          if (i < P_PARAM_N - 1) begin
            if (prev[i+1][j-1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
        end
        if (i > 0) begin
          if (prev[i-1][j] != 0) begin
            liveNum = liveNum + 1;
          end
        end
        if (i < P_PARAM_N - 1) begin
          if (prev[i+1][j] != 0) begin
            liveNum = liveNum + 1;
          end
        end
        if (j < P_PARAM_N - 1) begin
          if (i > 0) begin
            if (prev[i-1][j+1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
          if (i < P_PARAM_N - 1) begin
            if (prev[i+1][j+1] != 0) begin
              liveNum = liveNum + 1;
            end
          end
          if (prev[i][j+1] != 0) begin
            liveNum = liveNum + 1;
          end
        end
      end
      if (prev[i][j] == 0 && liveNum == 3) begin
        next[i][j] = 1;
      end else if (prev[i][j] == 1 && (liveNum == 2 || liveNum == 3)) begin
        next[i][j] = 1;
      end else begin
        next[i][j] = 0;
      end
    end
  end

endmodule
