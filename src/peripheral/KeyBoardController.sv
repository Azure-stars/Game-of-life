module KeyBoardController
#(parameter P_PARAM_N = 0, P_PARAM_M = 0, WIDTH = 12)
(
	input  wire clk_in,  // 50Mhz
	input  wire reset,   // reset_btn
    input wire ps2_clock,
    input wire ps2_data,
	output reg pause,						// 暂停功能
	output reg start,						// 开始/继续功能
	output reg clear,						// 清空页面，复位
	output reg [15:0] file_id,				// 使用的演化图像的 ID
	output reg reload,

	output reg [WIDTH - 1:0] shift_x,		// 演化图像的横向偏移量，为当前屏幕左上角的像素对应在原图像的横坐标
	output reg [WIDTH - 1:0] shift_y,		// 演化图像的纵向偏移量，为当前屏幕左上角的像素对应在原图像的纵坐标
	output reg [2:0] scroll,				// 演化图像的缩放等级
	output reg [3:0] evo_left_shift,  		// 演化速度等级
	output reg [31:0] display_color_id,		// 显示的颜色风格种类
	output wire [31:0] dpy_number,  		// 数码管
);
	
	wire [7:0] scancode;  					// PS2
	wire scancode_valid;  					// PS2
	reg [15:0] target_file_id;				// 目标演化图像的 ID，由键盘输入的十进制字符串转化为实际的编号
	reg [15:0] counter;						// 计数器
	reg running;							// 是否正在运行演化状态
	
	reg [7:0] last_code;					// 上一个键盘输入的键值

	reg [15:0] shift_x_;					// 临时变量，用于计算横向偏移量
	reg [15:0] shift_y_;					// 临时变量，用于计算纵向偏移量
	reg [15:0] shift_gird_size;				// 每次按键移动的单位栅格大小，由于存在缩放，因此每次移动可能会跨越多个像素
	
	reg [0:0] file_id_pos;  				// 当前输入的file id是位于十进制位还是个位，0 表示个位，1 表示十位。另外他还表示是否输入完成，若为 1 代表只输入了一半，需要等待继续输入
	reg [3:0] file_id_dig[1:0];  			// 当前输入的file id，file_id_dig[0] 表示十位，file_id_dig[1] 表示个位

	keyboard u_keyboard (
		.clock     (clk_in        ),
		.reset     (reset         ),
		.ps2_clock (ps2_clock     ),
		.ps2_data  (ps2_data      ),
		.scancode  (scancode      ),
		.valid     (scancode_valid)
	);
	
	// 计算目标演化图像的 ID
	assign target_file_id = (file_id_pos == 1'd0) ? file_id_dig[1] + (file_id_dig[0] << 3) + (file_id_dig[0] << 1) : target_file_id;
	// 展示当前文件 ID 的个位
	// 输入时先输十位再输个位，如果只输入了十位，那么十位在低位 LED 显示，高位为 0, target_file_id 不更新
	assign dpy_number[3:0] = (file_id_pos == 1'd0) ? file_id_dig[1] : file_id_dig[0];
	// 展示当前文件 ID 的十位
	assign dpy_number[7:4] = (file_id_pos == 1'd0) ? file_id_dig[0] : 4'd0;
	assign dpy_number[11:8] = evo_left_shift;

	// 计算每次按键移动的单位栅格大小。当缩放次数过大则不再缩放
	assign shift_gird_size = (scroll <= 4) ? (16'd16 >> scroll) : 1;

	always @(posedge clk_in or posedge reset) begin
		if (reset) begin
			running <= 0;
			pause <= 0;
			start <= 0;
			clear <= 0;
			file_id <= 16'd0;
			reload <= 0;
			// target_file_id <= 16'd0;
			counter <= 0;
			
			shift_x_ <= 16'd0;
			shift_y_ <= 16'd0;
			shift_x <= 16'd0;
			shift_y <= 16'd0;
			scroll <= 3'd0;
			evo_left_shift <= 4'd0;
			display_color_id <= 32'd0;
			
			// dpy_number <= 32'd0;
			file_id_pos <= 1'd0;
			file_id_dig[0] <= 8'd0;  // 高位
			file_id_dig[1] <= 8'd0;

			last_code <= 8'd0;
		end else begin
			if (shift_y_ + (P_PARAM_M >> scroll) <= P_PARAM_M) begin
				// 只有当这个偏移是合法的（即偏移量 + 缩放后的高小于等于原图像的高度）时才更新偏移量
				shift_y <= shift_y_;
			end else begin
				shift_y_ <= P_PARAM_M - (P_PARAM_M >> scroll);
			end
			if (shift_x_ + (P_PARAM_N >> scroll) <= P_PARAM_N) begin
				// 只有当这个偏移是合法的（即偏移量 + 缩放后的宽小于等于原图像的宽度）时才更新偏移量
				shift_x <= shift_x_;
			end else begin
				shift_x_ <= P_PARAM_N - (P_PARAM_N >> scroll);
			end
			if (scancode_valid) begin
				if (last_code != 8'b11110000) begin
					casez(scancode)
						8'b01000101: begin
							// 按下数字键 0 
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd0;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd0;
							end
						end
						8'b00010110: begin
							// 按下数字键 1
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd1;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd1;
							end
						end
						8'b00011110: begin
							// 按下数字键 2
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd2;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd2;
							end
						end
						8'b00100110: begin
							// 按下数字键 3
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd3;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd3;
							end
						end
						8'b00100101: begin
							// 按下数字键 4
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd4;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd4;
							end
						end
						8'b00101110: begin
							// 按下数字键 5
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd5;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd5;
							end
						end
						8'b00110110: begin
							// 按下数字键 6
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd6;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd6;
							end
						end
						8'b00111101: begin
							// 按下数字键 7
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd7;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd7;
							end
						end
						8'b00111110: begin
							// 按下数字键 8
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd8;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  evo_left_shift <= 4'd8;
							end
						end
						8'b01000110: begin
							// 按下数字键 9
							if(running == 0) begin
							  file_id_dig[file_id_pos] <= 4'd9;
							  file_id_pos <= file_id_pos + 1'd1;
							end else begin
							  // evo_left_shift <= 4'd9;
							end
						end
						8'b00101001: begin
							// 空格键，改变颜色风格
							if (display_color_id < 32'd7) begin
							   display_color_id <= display_color_id + 32'd1;
						   end else begin
							   display_color_id <= 0;
							end
						end
						8'b00001101: begin
						   // Tab 键，切换到下一个图形
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
						   // Shift，切换到上一个图形
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
						  	// P 键，暂停
						  	if(running == 1) begin
								pause <= 1;
								start <= 0;
								running <= 0;
								file_id_pos <= 1'd0;
						  	end
						end
						8'b01011010: begin
							// Enter 键，开始/继续
							if(running == 0) begin
								start <= 1;
								pause <= 0;
								running <= 1;
								file_id_pos <= 1'd0;
							end
						end
						8'b00101101: begin
·							// R 键，重新加载
							clear <= 1;
							start <= 0;
							pause <= 0;
							running <= 0;
							file_id_pos <= 1'd0;
							reload <= 1;
						end
						8'b01000001 : begin
							// 按下<键，减小演化速度
							if (evo_left_shift < 4'd8) begin
								evo_left_shift <= evo_left_shift + 4'd1;
							end
						end
						8'b01001001 : begin
							// 按下>键，增大演化速度
							if (evo_left_shift > 4'd0) begin
								evo_left_shift <= evo_left_shift - 4'd1;
							end
						end
						8'b01001110 : begin
							// 按下-键，缩小图形
							if (scroll > 3'd0) begin
								scroll <= scroll - 3'd1;
								shift_x_ <= shift_x_ - (P_PARAM_N >> (scroll + 3'd1));
								shift_y_ <= shift_y_ - (P_PARAM_M >> (scroll + 3'd1));
							end
						end
						8'b01010101 : begin
							// 按下+键，放大图形
							if (scroll < 3'd5) begin
								scroll <= scroll + 3'd1;
								shift_x_ <= shift_x_ + (P_PARAM_N >> (scroll + 3'd2));
								shift_y_ <= shift_y_ + (P_PARAM_M >> (scroll + 3'd2));
							end
						end
						8'b00011100: begin
							// 按下A键，图像左移		
							if (shift_x_ >= shift_gird_size) begin
								shift_x_ <= shift_x_ - shift_gird_size;
							end
						end
						8'b00011101: begin
							// 按下W键，图像上移
							if (shift_y_ >= shift_gird_size) begin
								shift_y_ <= shift_y_ - shift_gird_size;
							end
						end
						8'b00011011: begin
							// 按下S键，图像下移
							if (shift_y_ + (P_PARAM_M >> scroll) + shift_gird_size <= P_PARAM_M) begin
								shift_y_ <= shift_y_ + shift_gird_size;
							end
						end
						8'b00100011: begin
							// 按下D键，图像右移
							if (shift_x_ + (P_PARAM_N >> scroll) + shift_gird_size <= P_PARAM_N) begin
								shift_x_ <= shift_x_ + shift_gird_size;
							end
						end
						default: begin
						end
					endcase
				end
				last_code <= scancode;

				if (running == 0) begin
					// 如果文件 ID 输入完毕且和之前展示的文件 ID 不一致，或者 R 键复位
					// 那么就更新文件 ID 和当前已有的设置选项
					if ((file_id != target_file_id || reload == 1) && (file_id_pos == 1'd0)) begin
						shift_x_ <= 16'd0;
						shift_y_ <= 16'd0;
						shift_x <= 16'd0;
						shift_y <= 16'd0;
						scroll <= 3'd0;
					  	file_id <= target_file_id;
						reload <= 0;
					end
				end
			end else begin
				if (counter == 16'b1111111111111111) begin
					counter <= 0;
					pause <= 0;
					start <= 0;
					clear <= 0;
				end
				 else begin
					if (pause == 1 || start == 1 || clear == 1) begin
						counter <= counter + 1;
					end else begin
						counter = 0;
					end
				end
			end
		end
	end

endmodule
