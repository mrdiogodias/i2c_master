`timescale 1ns / 1ps


module i2c_master_tb;

reg clk       = 1'b0;
reg rst       = 1'b0;
reg start_i2c = 1'b0;
wire sda;
wire scl;
wire [3:0] error;
    
initial begin 
    #20000
    rst = 1'b1;
    #200
    rst = 1'b0;
    start_i2c = 1'b1;
    #200
    start_i2c = 1'b0;
    
    #400000
    rst = 1'b1;
    #10000
    rst = 1'b0;
    start_i2c = 1'b1;
    #200
    start_i2c = 1'b0;
    
end

i2c_master uut(clk, rst, start_i2c, error, sda, scl);

always #4 clk = ~clk;

endmodule
