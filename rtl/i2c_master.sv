`timescale 1ns / 1ps


module i2c_master(
    input  wire clk,
    input  wire rst,
    input  wire valid_cmd,
    output wire error,
    
    inout  wire sda,
    output wire scl
);

reg [15:0] addr  = 16'hAABB;
reg [23:0] data  = 24'hCDCDCD;

wire cu_ack;
wire dp_ack;
wire start_bit;
wire stop_bit;
wire send_addr;
wire send_data;
wire read_ack;
wire send_ack;
wire read_data;
wire repeated_start;

reg sda_i = 0;
reg sda_o;
reg sda_t;

IOBUF #(
    .DRIVE(12),             // Specify the output drive strength
    .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE" 
    .IOSTANDARD("DEFAULT"), // Specify the I/O standard
    .SLEW("SLOW")           // Specify the output slew rate
) IOBUF_inst(
    .O(sda_o),              // Buffer output
    .IO(sda),               // Buffer inout port (connect directly to top-level port)
    .I(sda_i),              // Buffer input
    .T(sda_t)               // 3-state enable input, high=input, low=output
    ); 

i2c_master_dp datapath(
    .clk(clk),
    .rst(rst), 
    .addr(addr), 
    .data(data),
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
    .sda_i(1'b0),
    .sda_o(sda_o)
);

i2c_master_cu control_unit(
    .clk(clk),
    .rst(rst),
    .valid_cmd(valid_cmd),
    .ack_i(dp_ack),
    .rw(addr[8]),
    .data_lenght(8'd3),
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

