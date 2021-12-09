`timescale 1ns / 1ps


module i2c_master_tb;

reg clk                 = 1'b0;
reg rst                 = 1'b1;
reg start_i2c           = 1'b1;
reg [7:0] addr          = 8'h0;
reg [71:0] data_to_send = 72'hDCAABBCCDD11223344;
reg [7:0] data_size     = 8'd3;
reg [15:0] prescaler    = 16'd624;

wire sda;
wire scl;
wire error;
wire [7:0] data_received;
wire valid_trans;
wire valid_recep; 

initial begin
    #20000
    rst = 1'b0;
    #200
    rst       = 1'b1;
    start_i2c = 1'b1;
    addr      = 8'hAB;
    #200
    start_i2c = 1'b0;
end

i2c_master i2c_unit(
    .clk(clk), 
    .rst(rst), 
    .start_i2c(start_i2c), 
    .addr(addr),
    .prescaler(prescaler),
    .data_to_send(data_to_send),
    .data_size(data_size),
    .data_received(data_received),
    .error(error), 
    .sda(sda), 
    .scl(scl),
    .valid_trans(valid_trans),
    .valid_recep(valid_recep)
);

always #4 clk = ~clk;

endmodule