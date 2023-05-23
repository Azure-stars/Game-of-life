module SDCardReader
#(parameter P_PARAM_W = 800, P_PARAM_H = 600, FILE_BLOCK = 7'b0)
(
    input  wire clk_spi,
    input  wire clk_ram,
	input  wire reset,
	 
    output wire        sd_sclk,     // SPI 时钟
    output wire        sd_mosi,
    input  wire        sd_miso,
    output wire        sd_cs,       // SPI 片选，低有效

	output reg        [23:0] address,
	output reg        write_data,
	output reg         rden,
	output reg         wren,
	input wire         read_data,
	

	
	input  wire [15:0] file_id,
	output reg read_file_finish
);

	localparam STATE_INIT = 2'd0;
	localparam STATE_READ = 2'd1;
	localparam STATE_FINISH = 2'd2;

	reg [15:0] current_file_id;
	reg [31:0] block_id;
	// reg [31:0] target_block_id;
	wire [7:0] mem [511:0];
	reg execute;
	reg [1:0] state_reg;


	reg [31:0] write_bit;

	SDCardBlockReader sd_card_block_reader(
		 .clk_spi            (clk_spi),
		 .reset              (reset),

		 .sd_cs              (sd_cs),
		 .sd_mosi            (sd_mosi),
		 .sd_miso            (sd_miso),
		 .sd_sclk            (sd_sclk),

		 .block_id           (block_id),
		 .execute            (execute),
		 .data               (mem),
		 .state_reg          (state_reg)
	);

	always @(posedge clk_ram or posedge reset) begin
		if (reset) begin
			current_file_id <= file_id;
  			block_id <= {32'b0, file_id, 7'b0};

			rden <= 0;
			wren <= 0;
			read_file_finish <= 0;
			write_bit <= 32'b0;
			address <= 32'b0;
			execute <= 0;
		end else begin
			if (read_file_finish == 0) begin
			  casez(state_reg)
					STATE_INIT: begin
					  execute = 0;
					end
					STATE_READ: begin
					  execute = 0;
					end
					STATE_FINISH: begin
						if (execute == 0) begin
							if (wren == 1) begin
								write_data <= mem[write_bit[11:3]][write_bit[2:0]];
								write_bit <= write_bit + 32'b1;
								address <= address + 32'b1;
								if (write_bit[11:0] == 12'd4095) begin
									wren <= 0;
									execute <= 1;
									if (block_id[6:0] == 7'd127) begin
										 read_file_finish <= 1;
									end
									else begin
										block_id <= block_id + 32'd1;
									end
								end
							end else begin
								wren <= 1;
							end
						end
					end
					default: begin
					  execute = 0;
					end
			  endcase
			end else begin
				if (file_id == current_file_id) begin
				end else begin
					current_file_id <= file_id;
					read_file_finish <= 0;
					block_id <= {32'b0, file_id, 7'b0};
					rden <= 0;
					wren <= 0;

					write_bit <= 32'b0;
					address <= 32'b0;
					execute <= 0;
				end
			end
		end
	end
	

endmodule


