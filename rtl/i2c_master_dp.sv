`timescale 1ns / 1ps


module i2c_master_dp(
    input  wire clk,
    input  wire rst,
    
    input  reg  [15:0] addr, 
    input  reg  [23:0] data,
    
    input  wire  start_bit,
    input  wire  stop_bit,
    input  wire  send_addr,
    input  wire  send_data,
    input  wire  read_ack, 
    input  wire  send_ack,
    input  wire  read_data, 
    input  wire  repeated_start,
    input  wire  ack_i,
    input  reg   sda_i,
    
    output reg   ack_o,
    output wire  scl,
    output reg   sda_o
);

reg scl_en          = 1'b0;
reg scl_reg         = 1'b1;
reg [23:0] addr_reg = 24'd0;
reg [23:0] data_reg = 24'd0;

assign scl = scl_reg;

always@(posedge clk) begin
    if(!rst) begin
        scl_en       <= 0;
        sda_o        <= 1;
        addr_reg     <= {addr, addr[15:8]};
        addr_reg[16] <= 1'b0;
        data_reg     <= data;
    end
    else begin
        if(start_bit) begin
            scl_en  <= 1;
            sda_o   <= 0;
        end
        if(stop_bit) begin
            scl_en  <= 0;
            sda_o   <= 1;
        end
    end
end

always@(posedge clk) begin
    if(scl_en)
        scl_reg <= ~scl_reg;
    else begin
        scl_reg <= 1;
    end
end

always@(negedge scl_reg) begin
    if(scl_en) begin
        if(send_addr) begin
            sda_o     <= addr_reg[23];
            addr_reg  <= {addr_reg[22:0], 1'b0};
        end
        
        if(send_data) begin
            sda_o     <= data_reg[23];
            data_reg  <= {data_reg[22:0], 1'b0};
        end
        
        if(send_ack) begin
            sda_o <= ack_i;
        end
        
        if(repeated_start) begin
            sda_o   <= 1;
        end
        
        if(read_ack) begin
            ack_o <= sda_i;
            sda_o <= 1'bz;
        end
        else 
            ack_o <= 1;
    end
    else 
        ack_o <= 1;
end

always@(posedge scl_reg) begin 
    if(scl_en) begin
        if(read_data) begin
            data_reg    <= {data_reg[22:0], 1'b0};
            data_reg[0] <= sda_i;
        end
    end
end


endmodule

