module i2c_master_tb;

reg clk = 1'b0;
reg rst = 1'b1;
reg valid_cmd = 1'b0;
wire sda;
wire scl;
    
initial begin 
    rst = 0;
    #10
    rst = 1;
    #2
    valid_cmd = 1;
    #10
    valid_cmd = 0;
end

i2c_master uut(clk, rst, valid_cmd, sda, scl);

always #5 clk = ~clk;

endmodule
