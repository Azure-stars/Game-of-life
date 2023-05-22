/// 手动单点修改
module Manual #(
    P_PARAM_M = 5,  // 行 
    P_PARAM_N = 5,  // 列
    WIDTH = 12     // 宽度
)(
    input wire clk,
    input wire modify,      // 修改标志，当上升沿到来时进行修改
    input wire read_val,    // 读入数据
    input wire read_address,// 读入地址
    output reg output_val,  // 写出数据
    output reg wden,        // 写使能
    output reg write_address// 写出地址
);
    parameter STATE_INIT = 0;
    parameter STATE_READ = 1;
    parameter STATE_WRITE = 2;
    parameter STATE_FINISH = 3;
    reg prev_modify;
    initial begin
        prev_modify = 0;
    end
    always @ (posedge clk) begin
        prev_modify <= modify;
        if (prev_modify != modify && modify == 1) begin
            wden <= 1;
            output_val <= ~read_val;
            write_address <= read_address;
        end
        else begin
            wden <= 0;
        end
    end

endmodule