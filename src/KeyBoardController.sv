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
	output reg [2:0] scroll,
	output reg [3:0] evo_left_shift,  // 速度偏移
	output wire [31:0] dpy_number  // 数码管
);
	
	wire [7:0] scancode;  // PS2
	wire scancode_valid;  // PS2
	reg [15:0] target_file_id;
	reg [15:0] counter;
	reg running;
	
	reg [7:0] last_code;

	reg [15:0] shift_x_;
	reg [15:0] shift_y_;
	
	reg [0:0] file_id_pos;  // 当前输入的file id十进制位
	reg [3:0] file_id_dig[1:0];  // 当前输入的file id十进制数

	keyboard u_keyboard (
		.clock     (clk_in        ),
		.reset     (reset         ),
		.ps2_clock (ps2_clock     ),
		.ps2_data  (ps2_data      ),
		.scancode  (scancode      ),
		.valid     (scancode_valid)
	);
	
	assign target_file_id = (file_id_pos == 1'd0) ? file_id_dig[1] + (file_id_dig[0] << 3) + (file_id_dig[0] << 1) : target_file_id;
	assign dpy_number[3:0] = (file_id_pos == 1'd0) ? file_id_dig[1] : file_id_dig[0];
	assign dpy_number[7:4] = (file_id_pos == 1'd0) ? file_id_dig[0] : 4'd0;

	always @(posedge clk_in or posedge reset) begin
		if (reset) begin
			running <= 0;
			pause <= 0;
			start <= 0;
			clear <= 0;
			file_id <= 16'd0;
			// target_file_id <= 16'd0;
			counter <= 0;
			
			shift_x_ <= 16'd0;
			shift_y_ <= 16'd0;
			shift_x <= 16'd0;
			shift_y <= 16'd0;
			scroll <= 3'd0;
			evo_left_shift <= 4'd0;
			
			// dpy_number <= 32'd0;
			file_id_pos <= 1'd0;
			file_id_dig[0] <= 8'd0;  // 高位
			file_id_dig[1] <= 8'd0;

			last_code <= 8'd0;
		end else begin
			// dpy_number[3:0] <= file_id_dig[1];
			// dpy_number[7:4] <= file_id_dig[0];
			if (shift_y_ + (P_PARAM_M >> scroll) <= P_PARAM_M) begin
				shift_y <= shift_y_;
			end else begin
				shift_y_ <= P_PARAM_M - (P_PARAM_M >> scroll);
			end
			if (shift_x_ + (P_PARAM_N >> scroll) <= P_PARAM_N) begin
				shift_x <= shift_x_;
			end else begin
				shift_x_ <= P_PARAM_N - (P_PARAM_N >> scroll);
			end
			if (scancode_valid) begin
				if (last_code != 8'b11110000) begin
					casez(scancode)
						8'b01000101: begin
							// target_file_id <= 16'd0;
							file_id_dig[file_id_pos] <= 4'd0;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00010110: begin
							// target_file_id <= 16'd1;
							file_id_dig[file_id_pos] <= 4'd1;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00011110: begin
							// target_file_id <= 16'd2;
							file_id_dig[file_id_pos] <= 4'd2;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00100110: begin
							// target_file_id <= 16'd3;
							file_id_dig[file_id_pos] <= 4'd3;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00100101: begin
							// target_file_id <= 16'd4;
							file_id_dig[file_id_pos] <= 4'd4;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00101110: begin
							// target_file_id <= 16'd5;
							file_id_dig[file_id_pos] <= 4'd5;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00110110: begin
							// target_file_id <= 16'd6;
							file_id_dig[file_id_pos] <= 4'd6;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00111101: begin
							// target_file_id <= 16'd7;
							file_id_dig[file_id_pos] <= 4'd7;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00111110: begin
							// target_file_id <= 16'd8;
							file_id_dig[file_id_pos] <= 4'd8;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b01000110: begin
							// target_file_id <= 16'd9;
							file_id_dig[file_id_pos] <= 4'd9;
							file_id_pos <= file_id_pos + 1'd1;
						end
						8'b00001101: begin
						   // Tab
							if (file_id_dig[1] == 4'd9) begin
							  if (file_id_dig[0] == 4'd9) begin
							    file_id_dig[0] <= 4'd0;
							    file_id_dig[1] <= 4'd0;
							  end else begin
							    file_id_dig[1] <= 4'd0;
							    file_id_dig[0] <= file_id_dig[0] + 4'd1;
							  end
							end else begin
							  file_id_dig[1] <= file_id_dig[1] + 4'd1;
							end
							file_id_pos <= 1'd0;
						end
						8'b00010010: begin
						   // Shift
							if (file_id_dig[1] == 4'd0) begin
							  if (file_id_dig[0] == 4'd0) begin
							    file_id_dig[0] <= 4'd9;
							    file_id_dig[1] <= 4'd9;
							  end else begin
							    file_id_dig[1] <= 4'd9;
							    file_id_dig[0] <= file_id_dig[0] - 4'd1;
							  end
							end else begin
							  file_id_dig[1] <= file_id_dig[1] - 4'd1;
							end
							file_id_pos <= 1'd0;
						end
						8'b01001101: begin
						  if(running == 1) begin
						    // Pause
							 pause <= 1;
							 start <= 0;
							 running <= 0;
							 manual <= 0;
							 file_id_pos <= 1'd0;
			             file_id_dig[0] <= 8'd0;
			             file_id_dig[1] <= 8'd0;
						  end
						end
						8'b01011010: begin
						  if(running == 0) begin
						    // Enter
					       start <= 1;
						    pause <= 0;
						    running <= 1;
						    manual <= 0;
							 file_id_pos <= 1'd0;
			             file_id_dig[0] <= 8'd0;
			             file_id_dig[1] <= 8'd0;
						  end
						end
						8'b00101101: begin
						   // Reset
							// target_file_id <= 16'd0;
							clear <= 1;
							start <= 0;
							pause <= 0;
							running <= 0;
							manual <= 0;
							file_id_pos <= 1'd0;
			            file_id_dig[0] <= 8'd0;
			            file_id_dig[1] <= 8'd0;
						end
						8'b01000001 : begin
							// 按下<键
							if (evo_left_shift < 4'd5) begin
								evo_left_shift <= evo_left_shift + 4'd1;
							end
						end
						8'b01001001 : begin
							// 按下>键
							if (evo_left_shift > 4'd0) begin
								evo_left_shift <= evo_left_shift - 4'd1;
							end
						end
						8'b01001110 : begin
							// 按下-键
							if (scroll > 3'd0) begin
								scroll <= scroll - 3'd1;
								shift_x_ <= shift_x_ - (P_PARAM_N >> (scroll + 3'd1));
								shift_y_ <= shift_y_ - (P_PARAM_M >> (scroll + 3'd1));
							end
						end
						8'b01010101 : begin
							// 按下+键
							if (scroll < 3'd5) begin
								scroll <= scroll + 3'd1;
								shift_x_ <= shift_x_ + (P_PARAM_N >> (scroll + 3'd2));
								shift_y_ <= shift_y_ + (P_PARAM_M >> (scroll + 3'd2));
							end
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
								if (shift_x_ > 16'd0) begin
									shift_x_ <= shift_x_ - 16'b1;
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
								if (shift_y_ > 16'd0) begin
									shift_y_ <= shift_y_ - 16'b1;
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
								if (shift_y_ + (P_PARAM_M >> scroll) < P_PARAM_M) begin
									shift_y_ <= shift_y_ + 16'b1;
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
								if (shift_x_ + (P_PARAM_N >> scroll) < P_PARAM_N) begin
									shift_x_ <= shift_x_ + 16'b1;
								end
							end
						end
						default: begin
						end
					endcase
				end
				last_code <= scancode;
				// if (file_id_pos == 1'd0) begin
				  // target_file_id <= file_id_dig[1] + (file_id_dig[0] << 3) + (file_id_dig[0] << 1);
				// end
				if (running == 0) begin
					if ((file_id != target_file_id) && (file_id_pos == 1'd0)) begin
						shift_x_ <= 16'd0;
						shift_y_ <= 16'd0;
						shift_x <= 16'd0;
						shift_y <= 16'd0;
						scroll <= 3'd0;
						evo_left_shift <= 4'd2;
					   file_id <= target_file_id;
					end
				end
			end else begin
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
