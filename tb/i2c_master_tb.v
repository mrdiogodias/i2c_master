`timescale 1ns / 1ps


module i2c_master_tb;

reg clk       = 1'b0;
reg rst       = 1'b0;
reg valid_cmd = 1'b1;
wire sda;
wire scl;
wire [3:0] error;
    
initial begin 
    #200
    rst = 1'b1;
    #200
    rst = 1'b0;
    #20000
    rst = 1'b1;
    #2000
    rst = 1'b0;
end

i2c_master uut(clk, rst, valid_cmd, error, sda, scl);

always #5 clk = ~clk;

endmodule
