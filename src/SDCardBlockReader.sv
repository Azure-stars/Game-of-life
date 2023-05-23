module SDCardBlockReader  // 读取编号为block_id的block中的数据(512 * 8 bit)，存入data中
(
	input  wire clk_spi,
	input  wire reset,

   output wire        sd_sclk,     // SPI 时钟
   output wire        sd_mosi,
   input  wire        sd_miso,
   output wire        sd_cs,       // SPI 片选，低有效
//   input  wire        sd_cd,       // 卡插入检测，0 表示有卡插入
//   input  wire        sd_wp,       // 写保护检测，0 表示写保护状态

	input  reg [31:0] block_id,
	input  wire execute,
	output reg [7:0] data [511:0],
	output reg [1:0] state_reg

);

	localparam STATE_INIT = 2'd0;
	localparam STATE_READ = 2'd1;
	localparam STATE_FINISH = 2'd2;

	reg [31:0] sdc_address;
	wire sdc_ready;

	reg sdc_read;
	wire [7:0] sdc_read_data;
	wire sdc_read_valid;

	reg sdc_write;
	reg [7:0] sdc_write_data;
	wire sdc_write_ready;

	sd_controller u_sd_controller (
		 .clk                (clk_spi),
		 .reset              (reset),

		 .cs                 (sd_cs),
		 .mosi               (sd_mosi),
		 .miso               (sd_miso),
		 .sclk               (sd_sclk),

		 .address            (sdc_address),
		 .ready              (sdc_ready),

		 .rd                 (sdc_read),
		 .dout               (sdc_read_data),
		 .byte_available     (sdc_read_valid),

		 .wr                 (sdc_write),
		 .din                (sdc_write_data),
		 .ready_for_next_byte(sdc_write_ready)
	);

   reg [9:0] write_byte;

	always @(posedge clk_spi or posedge reset or posedge execute) begin
		 if (execute) begin
			  sdc_address <= block_id;
			  sdc_read <= 1'b0;
			  sdc_write <= 1'b0;
			  sdc_write_data <= 8'b0;
			  state_reg <= STATE_INIT;
			  write_byte <= 10'b0;
		 end else if (reset) begin
			  sdc_address <= block_id;
			  sdc_read <= 1'b0;
			  sdc_write <= 1'b0;
			  sdc_write_data <= 8'b0;

			  state_reg <= STATE_INIT;
			  write_byte <= 10'b0;
		 end else begin
			  casez(state_reg)
					STATE_INIT: begin
						 if (sdc_ready) begin
							  sdc_read <= 1'b1;
							  state_reg <= STATE_READ;
						 end
					end
					STATE_READ: begin
						 sdc_read <= 1'b0;
						 if (sdc_read_valid) begin
							  data[write_byte] <= sdc_read_data;
							  write_byte <= write_byte + 10'd1;
						 end
						 if (write_byte == 10'd512) begin
							  state_reg <= STATE_FINISH;
						 end
					end
					default: begin
					end
			  endcase
		 end
	end

endmodule
