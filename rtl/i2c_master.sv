`timescale 1ns / 1ps


module i2c_master #(
    parameter DATA_WIDTH = 8 /* Max number of bytes that can be sent in each write operation */
)(
    input  wire clk,
    input  wire rst,
    input  wire valid_cmd,
    output wire [3:0] error,
    
    output wire sda,
    output wire scl
);

reg [15:0] addr                       = 16'hABBB; /* 1st byte - Slave address | 2nd byte - Register address */
reg [(DATA_WIDTH * 8) - 1:0] data_in  = 64'hCDCCCDCDAAAAAAAA; /* Data to send (max of 8 bytes) */
reg [7:0] data_out; /* Data received is stored in this reg */

wire cu_ack; /* ack from cu to dp (from I2C master to I2C slave) */
wire dp_ack; /* ack from dp to cu (from I2C slave to I2C master) */
wire start_bit;
wire stop_bit;
wire send_addr;
wire send_data;
wire read_ack;
wire send_ack;
wire read_data;
wire repeated_start;

wire sda_i;
wire sda_o;
wire sda_t;

wire clk_sys;
wire rst_sys_n;

assign sda = sda_t ? 1'b0 : sda_o;


/*clk_wiz_0 clk_wizard(
    .clk_out1(clk_sys),
    .resetn(~rst),
    .locked(rst_sys_n),
    .clk_in1(clk)
);*/

/*IOBUF #(
    .DRIVE(12),             // Specify the output drive strength
    .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE" 
    .IOSTANDARD("DEFAULT"), // Specify the I/O standard
    .SLEW("SLOW")           // Specify the output slew rate
) IOBUF_inst(
    .O(sda_i),              // Buffer output
    .IO(sda),               // Buffer inout port (connect directly to top-level port)
    .I(sda_o),              // Buffer input
    .T(sda_t)               // 3-state enable input, high=input, low=output
    ); */

i2c_master_dp #(
    .DATA_WIDTH(DATA_WIDTH)
) 
datapath (
    .clk(clk),//clk_sys),
    .rst(~rst),//rst_sys_n), 
    .addr(addr), 
    .data_in(data_in),
    .data_out(data_out),
    .start_bit(start_bit),
    .stop_bit(stop_bit),
    .send_addr(send_addr),
    .send_data(send_data),
    .read_ack(read_ack), 
    .send_ack(send_ack),
    .read_data(read_data),
    .repeated_start(repeated_start),
    .ack_o(dp_ack),
    .ack_i(cu_ack),
    .scl(scl),
    .sda_i(1'b0), /* Always ack = 0 for debug purposes */
    .sda_o(sda_o)
);

i2c_master_cu control_unit(
    .clk(clk),//clk_sys),
    .rst(~rst),//rst_sys_n)
    .valid_cmd(1'b1), /* Always valid for debug purposes */
    .ack_i(dp_ack),
    .rw(addr[8]),
    .data_lenght(8'd2), /* In case of a write send 2 bytes */
    .ack_o(cu_ack),
    .start_bit(start_bit),
    .stop_bit(stop_bit),
    .repeated_start(repeated_start),
    .send_addr(send_addr),
    .send_data(send_data),
    .read_ack(read_ack), 
    .send_ack(send_ack),
    .read_data(read_data),
    .error(error),
    .sda_t(sda_t)
);

endmodule
