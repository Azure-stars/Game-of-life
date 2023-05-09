module KeyBoardController
(
	 input  wire clk_in,  // 100Mhz
	 input  wire reset,   // reset_btn
    input wire ps2_clock,
    input wire ps2_data,
	 output wire pause,
	 output wire start,
	 output wire clear,
	 output reg [7:0] file_id
);
	
	wire [7:0] scancode;  // PS2
	wire scancode_valid;  // PS2
	wire [7:0] target_file_id;
	wire [15:0] counter;
	reg running;
	
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
			  file_id <= 0;
			  target_file_id <= 0;
			  counter <= 0;
		 end else begin
			  if (scancode_valid) begin
					casez(scancode)
						 8'b01000101: begin
							  target_file_id <= 0;
						 end
						 8'b00010110: begin
							  target_file_id <= 1;
						 end
						 8'b00011110: begin
							  target_file_id <= 2;
						 end
						 8'b00100110: begin
							  target_file_id <= 3;
						 end
						 8'b00100101: begin
							  target_file_id <= 4;
						 end
						 8'b00101110: begin
							  target_file_id <= 5;
						 end
						 8'b00110110: begin
							  target_file_id <= 6;
						 end
						 8'b00111101: begin
							  target_file_id <= 7;
						 end
						 8'b00111110: begin
							  target_file_id <= 8;
						 end
						 8'b01000110: begin
							  target_file_id <= 9;
						 end
						 8'b01001101: begin
							  pause <= 1;
							  running <= 0;
						 end
						 8'b01011010: begin
							  start <= 1;
							  running <= 1;
						 end
						 8'b00101101: begin
							  clear <= 1;
							  running <= 0;
						 end
						 default: begin
						     pause <= 0;
							  start <= 0;
							  clear <= 0;
						 end
					endcase
					
					if (running == 0) begin
					    file_id <= target_file_id;
					end
			  end else begin
			     if (counter == 15'b1111111111111111) begin
				      counter <= 0;
					   pause <= 0;
					   start <= 0;
					   clear <= 0;
				  end else begin
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
