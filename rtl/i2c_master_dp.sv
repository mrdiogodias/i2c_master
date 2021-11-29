`timescale 1ns / 1ps


module i2c_master_dp#(
    parameter DATA_WIDTH = 4 /* Max number of bytes that can be sent in each write operation */
)(
    input  wire clk,
    input  wire rst,
    
    input  reg  [7:0] addr, 
    input  reg  [(DATA_WIDTH * 8) - 1:0] data_in,  /* Data to send. 1st byte is the register addr */
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
    
    input  wire  scl,
    input  wire  p_edge,
    input  wire  n_edge,
    
    output reg   ack_o,
    
    output reg   sda_o,
    input  reg   sda_i
);


/* addr_reg is 2 bytes because of the read operation 
1st byte - Slave addr (with the last bit always = wr = 0)
2nd byte - Slave addr (with the real wr). This byte is only used in reads and when wr = 1 */
reg [15:0] addr_reg                      = 0; 
reg [(DATA_WIDTH * 8) - 1:0] data_in_reg = 0;
initial sda_o = 1'b1;


always@(posedge clk) begin
    if(!rst) begin
        sda_o        <= 1'b1;
        ack_o        <= 1'b1;
    end
    else begin
        if(start_bit) begin
            sda_o        <= 1'b0;
            data_in_reg  <= data_in;
            if(!repeated_start) begin
                addr_reg <= {addr[7:1], 1'b0, addr};
            end
        end
        
        else if(stop_bit) begin
            if(p_edge) begin
                sda_o <= 1'b1;
            end
            else begin
                sda_o <= 1'b0;
            end
        end
        
        else if(repeated_start) begin
            if(p_edge) begin
                sda_o <= 1'b0;
            end 
            else begin
                sda_o <= 1'b1;
            end
        end
    
        if(read_ack) begin
            ack_o <= sda_i;
        end
        else begin
            ack_o <= 1'b1;
        end
        
        /* Scl negedge */
        if(n_edge) begin
            if(send_addr) begin
                sda_o       <= addr_reg[15];
                addr_reg    <= {addr_reg[14:0], 1'b0};
            end
            
            else if(send_data) begin
                sda_o       <= data_in_reg[(DATA_WIDTH * 8) - 1];
                data_in_reg <= {data_in_reg[(DATA_WIDTH * 8) - 2:0], 1'b0};
            end
            
            else if(send_ack) begin
                sda_o <= ack_i;
            end
        end
        
        /* Scl posedge */
        if(p_edge) begin
            if(read_data) begin
                data_out    <= {data_out[6:0], sda_i};
                sda_o       <= 1'b0;
            end
        end
    end
end 

endmodule
