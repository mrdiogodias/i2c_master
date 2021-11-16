`timescale 1ns / 1ps


module i2c_master_dp#(
    parameter DATA_WIDTH = 4 /* Max number of bytes that can be sent in each write operation */
)(
    input  wire clk,
    input  wire rst,
    
    input  reg  [15:0] addr, /* 1st byte - Slave address | 2nd byte - Register address */
    input  reg  [(DATA_WIDTH * 8) - 1:0] data_in,  /* Data to send (max of 8 bytes) */
    output reg  [7:0] data_out, /* Data received is stored in this reg */
    
    /* Control signals */
    input  wire  start_bit,
    input  wire  stop_bit,
    input  wire  send_addr,
    input  wire  send_data,
    input  wire  read_ack, 
    input  wire  send_ack,
    input  wire  read_data, 
    input  wire  repeated_start,
    input  wire  ack_i,
    
    output wire  scl,
    output reg   ack_o,
    
    output reg   sda_o,
    input  reg   sda_i
);

reg i2c_en                               = 1'b0;
reg scl_reg                              = 1'b1;
reg [(DATA_WIDTH * 8) - 1:0] data_in_reg = 0;
/* addr_reg is 3 bytes because in case of a read: 
1st byte - Slave addr (with the last bit = wr = 0)
2nd byte - Register addr
3rd byte - Slave addr (with the last bit = wr = 1) */
reg [23:0] addr_reg                      = 0; 

assign scl = scl_reg;

always@(posedge clk) begin
    if(!rst) begin
        i2c_en       <= 1'b0;
        sda_o        <= 1'b1;
        scl_reg      <= 1'b1;
    end
    else begin
        if(start_bit) begin
            i2c_en   <= 1'b1;
            sda_o    <= 1'b0;
            /* If is indeed a start bit and not a repeated start */
            if(!i2c_en) begin
                addr_reg     <= {addr, addr[15:8]};
                addr_reg[16] <= 1'b0;
                data_in_reg  <= data_in;
            end
        end
        
        if(stop_bit) begin
            i2c_en  <= 0;
            sda_o   <= 1;
        end
        
        if(i2c_en) begin
            scl_reg <= ~scl_reg;
            
            /* Negedge scl */
            if(scl_reg) begin
                
                if(send_addr) begin
                    sda_o       <= addr_reg[23];
                    addr_reg    <= {addr_reg[22:0], 1'b0};
                end
                
                if(send_data) begin
                    sda_o       <= data_in_reg[(DATA_WIDTH * 8) - 1];
                    data_in_reg <= {data_in_reg[(DATA_WIDTH * 8) - 2:0], 1'b0};
                end
                
                if(send_ack) begin
                    sda_o <= ack_i;
                end
                
                if(repeated_start) begin
                    sda_o <= 1'b1;
                end
                
                if(read_ack) begin
                    ack_o <= sda_i;
                end
            end
            
            /* Posedge scl */
            else begin 
                if(read_data) begin
                    data_out    <= {data_out[6:0], 1'b0};
                    data_out[0] <= sda_i;
                end
            end
        end
        else begin
            scl_reg <= 1'b1;
            ack_o   <= 1'b1;
        end
        
    end
end

endmodule
