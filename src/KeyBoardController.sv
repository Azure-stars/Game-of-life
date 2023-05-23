module KeyBoardController
#(parameter P_PARAM_N = 0, P_PARAM_M = 0)
(
	input  wire clk_in,  // 50Mhz
	input  wire reset,   // reset_btn
    input wire ps2_clock,
    input wire ps2_data,
	output reg pause,
	output reg start,
	output reg clear,
	output reg manual,				// 手动设置
	output reg [3:0] setting,		// 手动设置状态下的移动，0b0001为A，0b0010为W，0b0100为S，0b1000为D
	output reg [15:0] file_id,

	output reg [15:0] shift_x,
	output reg [15:0] shift_y,
	output reg [2:0] scroll
);
	
	wire [7:0] scancode;  // PS2
	wire scancode_valid;  // PS2
	reg [15:0] target_file_id;
	reg [15:0] counter;
	reg running;
	
	reg [7:0] last_code;
	
	keyboard u_keyboard (
		.clock     (clk_in        ),
		.reset     (reset         ),
		.ps2_clock (ps2_clock     ),
		.ps2_data  (ps2_data      ),
		.scancode  (scancode      ),
		.valid     (scancode_valid)
	);

	always @(posedge clk_in or posedge reset) begin
		if (reset) begin
			running <= 0;
			pause <= 0;
			start <= 0;
			clear <= 0;
			file_id <= 16'd0;
			target_file_id <= 16'd0;
			counter <= 0;
			
			shift_x <= 16'd0;
			shift_y <= 16'd0;
			scroll <= 3'd0;
			
			last_code <= 8'd0;
		end else begin
			if (scancode_valid) begin
				if (last_code != 8'b11110000) begin
					casez(scancode)
						8'b01000101: begin
							target_file_id <= 16'd0;
						end
						8'b00010110: begin
							target_file_id <= 16'd1;
						end
						8'b00011110: begin
							target_file_id <= 16'd2;
						end
						8'b00100110: begin
							target_file_id <= 16'd3;
						end
						8'b00100101: begin
							target_file_id <= 16'd4;
						end
						8'b00101110: begin
							target_file_id <= 16'd5;
						end
						8'b00110110: begin
							target_file_id <= 16'd6;
						end
						8'b00111101: begin
							target_file_id <= 16'd7;
						end
						8'b00111110: begin
							target_file_id <= 16'd8;
						end
						8'b01000110: begin
							target_file_id <= 16'd9;
						end
						8'b01001101: begin
						if(running == 1) begin
							pause <= 1;
							start <= 0;
							running <= 0;
							manual <= 0;
						end
						end
						8'b01011010: begin
						if(running == 0) begin
							start <= 1;
							pause <= 0;
							running <= 1;
							manual <= 0;
						end
						end
						8'b00101101: begin
							clear <= 1;
							start <= 0;
							pause <= 0;
							running <= 0;
							manual <= 0;
						end
						8'b01001110 : begin
							// 按下-键
							scroll <= scroll - 3'd1;
						end
						8'b01010101 : begin
							// 按下+键
							scroll <= scroll + 3'd1;
						end
						8'b00111010 : begin
							// 按下M键
							if (running == 0) begin
								manual <= 1;
								clear <= 0;
								start <= 0;
								pause <= 0;
							end
						end
						8'b00110001 : begin
							// 按下N键
							if (manual == 1) begin
								manual <= 0;
								clear <= 0;
								start <= 0;
								pause <= 0;
							end
						end
						8'b00011100: begin
							// 按下A键
							if (manual == 1) begin
								// 仅在非运行状态下才可以使用手动设置
								setting <= 4'b0001;
								// 不改变其他状态
							end else begin
								if (shift_x > 16'd0) begin
									shift_x <= shift_x - 16'b1;
								end
							end
						end
						8'b00011101: begin
							// 按下W键
							if (manual == 1) begin
								// 仅在非运行状态下才可以使用手动设置
								setting <= 4'b0010;
								// 不改变其他状态
							end else begin
								if (shift_y > 16'd0) begin
									shift_y <= shift_y - 16'b1;
								end
							end
						end
						8'b00011011: begin
							// 按下S键
							if (manual == 1) begin
								// 仅在非运行状态下才可以使用手动设置
								setting <= 4'b0100;
								// 不改变其他状态
							end else begin
								if (shift_y + (P_PARAM_M >> scroll) < P_PARAM_M) begin
									shift_y <= shift_y + 16'b1;
								end
							end
						end
						8'b00100011: begin
							// 按下D键
							if (manual == 1) begin
								// 仅在非运行状态下才可以使用手动设置
								setting <= 4'b1000;
								// 不改变其他状态
							end else begin
								if (shift_x + (P_PARAM_N >> scroll) < P_PARAM_N) begin
									shift_x <= shift_x + 16'b1;
								end
							end
						end
						default: begin
	//						     pause <= 1;
	//							  start <= 0;
	//							  clear <= 0;
						end
					endcase
				end
				last_code <= scancode;
				if (running == 0) begin
					file_id <= target_file_id;
				end
			end else begin
				setting <= 0;
				// pause <= 0;
				// start <= 0;
				// clear <= 0;
				if (counter == 16'b1111111111111111) begin
					counter <= 0;
					pause <= 0;
					start <= 0;
					clear <= 0;
					// manual <= 0;
				end
				 else begin
					if (pause == 1 || start == 1 || clear == 1 || manual == 1) begin
						counter <= counter + 1;
					end else begin
						counter = 0;
					end
				end
			end
		end
	end

endmodule
