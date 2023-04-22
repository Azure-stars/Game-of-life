# Module document

> 开发人员：郑友捷、宋曦轩

> 说明：
>
> 本文档用于记录《数字逻辑设计》课程实验设计过程中运用到的模块，方便统一接口，规范开发

## evolution

### 功能

在给定当前状态的情况下，实现**单次生命游戏演化**过程并给出本轮演化的结果

### 定义

```verilog
module evolution (
    input reg [9999:0] prev,
    output reg [9999:0] next
);
    
endmodule
```

### 字段说明

* prev：初始化或者上一轮演化的结果，以一维形式输入表示二维形式。若长度为10000，代表100*100的界面。
* next：经过本次演化之后得到的结果，同样以一维形式输出代表二维形式。转化方法如上。



## Iteration

### 功能

在给定初始状态下，依据时钟周期进行生命游戏演化，同时可以控制暂停与继续。

### 定义

```verilog
module evolution (
    input wire CLK,
    input wire pause,
    input reg [9999:0] init,
    output reg [9999:0] status
);
    
endmodule
```

### 字段说明

* CLK：时钟周期
* pause：控制是否暂停
* init：初始化状态
* status：当前的输出状态



## SD_cmd

### 功能

实现SD卡的读写操作

**注：我找到的博客是在一个module实现读写的([FPGA之SD卡读写操作_fpga sd卡读写_打气瓶的博客-CSDN博客](https://blog.csdn.net/weixin_41892263/article/details/83039174))，你可以把它分开为读和写两个模块**

### 定义

```verilog
module sd_card_cmd(
	input                       sys_clk,
	input                       rst,
	input[15:0]                 spi_clk_div,                  //SPI module clock division parameter
	input                       cmd_req,                      //SD card command request
	output                      cmd_req_ack,                  //SD card command request response
	output reg                  cmd_req_error,                //SD card command request error
	input[47:0]                 cmd,                          //SD card command
	input[7:0]                  cmd_r1,                       //SD card expect response
	input[15:0]                 cmd_data_len,                 //SD card command read data length
	input                       block_read_req,               //SD card sector data read request
	output reg                  block_read_valid,             //SD card sector data read data valid
	output reg[7:0]             block_read_data,              //SD card sector data read data
	output                      block_read_req_ack,           //SD card sector data read response
	input                       block_write_req,              //SD card sector data write request
	input[7:0]                  block_write_data,             //SD card sector data write data next clock is valid
	output                      block_write_data_rd,          //SD card sector data write data
	output                      block_write_req_ack,          //SD card sector data write response
	output                      nCS_ctrl,                     //SPI module chip select control
	output reg[15:0]            clk_div,
	output reg                  spi_wr_req,                   //SPI module data sending request
	input                       spi_wr_ack,                   //SPI module data request response
	output[7:0]                 spi_data_in,                  //SPI module send data
	input[7:0]                  spi_data_out                  //SPI module data returned
)
endmodule
```

### 字段说明

详见注释