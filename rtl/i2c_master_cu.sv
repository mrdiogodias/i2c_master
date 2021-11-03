`timescale 1ns / 1ps


module i2c_master_cu(
    input  wire clk,
    input  wire rst,
    input  wire valid_cmd,
    
    input  wire ack_i,
    input  wire rw, /* 0 -> write; 1 -> read */
    input  wire [7:0] data_lenght, /* number of bytes to send */
 
    output reg  ack_o, 
    output reg  start_bit,
    output reg  stop_bit,
    output reg  send_addr,
    output reg  send_data,
    output reg  read_ack, 
    output reg  repeated_start,
    output reg  send_ack,
    output reg  read_data,
    output wire error,
    output reg  sda_t
);

localparam [4:0]
    STATE_IDLE              = 4'd0,
    STATE_START             = 4'd1,
    STATE_DEVICE_ADDR       = 4'd2,
    STATE_DEVICE_ADDR_ACK   = 4'd3,
    STATE_REGISTER_ADDR     = 4'd4,
    STATE_REGISTER_ADDR_ACK = 4'd5,
    STATE_REPEATED_START    = 4'd6,
    STATE_READ              = 4'd7, 
    STATE_READ_ACK          = 4'd8,
    STATE_WRITE             = 4'd9,
    STATE_WRITE_ACK         = 4'd10,
    STATE_STOP              = 4'd11,
    STATE_ERROR             = 4'd12;
    
reg  [4:0] state;
wire [4:0] next_state;

reg addr_sent           = 1'b0;
reg data_received       = 1'b0;
reg data_sent           = 1'b0;
reg byte_sent           = 1'b0;
reg repeated_start_done = 1'b0;
reg stop_done           = 1'b0;
reg [4:0] bit_count_reg = 5'd0, bit_count_next;
reg [7:0] data_len_reg  = 8'd0;

assign error = (state == STATE_ERROR) ? 1 : 0;

always@(posedge clk) begin
    if(!rst) begin
        state         <= STATE_IDLE;
    end
    else begin
        state         <= next_state;
        bit_count_reg <= bit_count_next;
    end
end

assign next_state = (state == STATE_IDLE & valid_cmd)                      ? STATE_START :
                    (state == STATE_IDLE & ~valid_cmd)                     ? STATE_IDLE : 
                    (state == STATE_START)                                 ? STATE_DEVICE_ADDR:
                    (state == STATE_DEVICE_ADDR & byte_sent)               ? STATE_DEVICE_ADDR_ACK:
                    (state == STATE_DEVICE_ADDR & ~byte_sent)              ? STATE_DEVICE_ADDR:
                    (state == STATE_DEVICE_ADDR_ACK & ack_i)               ? STATE_ERROR:
                    (state == STATE_DEVICE_ADDR_ACK & ~ack_i & addr_sent)  ? STATE_READ:
                    (state == STATE_DEVICE_ADDR_ACK & ~ack_i & ~addr_sent) ? STATE_REGISTER_ADDR:
                    (state == STATE_REGISTER_ADDR & byte_sent)             ? STATE_REGISTER_ADDR_ACK :
                    (state == STATE_REGISTER_ADDR & ~byte_sent)            ? STATE_REGISTER_ADDR :
                    (state == STATE_REGISTER_ADDR_ACK & ack_i)             ? STATE_ERROR :
                    (state == STATE_REGISTER_ADDR_ACK & ~ack_i & rw)       ? STATE_REPEATED_START :
                    (state == STATE_REGISTER_ADDR_ACK & ~ack_i & ~rw)      ? STATE_WRITE :
                    (state == STATE_REPEATED_START & ~repeated_start_done) ? STATE_REPEATED_START:
                    (state == STATE_REPEATED_START & repeated_start_done)  ? STATE_DEVICE_ADDR:
                    (state == STATE_READ & data_received)                  ? STATE_READ_ACK:
                    (state == STATE_READ & ~data_received)                 ? STATE_READ:
                    (state == STATE_READ_ACK & ack_o)                      ? STATE_ERROR :
                    (state == STATE_READ_ACK & ~ack_o)                     ? STATE_STOP :
                    (state == STATE_WRITE & byte_sent)                     ? STATE_WRITE_ACK :
                    (state == STATE_WRITE & ~byte_sent)                    ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ack_i)                     ? STATE_ERROR :
                    (state == STATE_WRITE_ACK & ~ack_i & ~data_sent)       ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ~ack_i & data_sent)        ? STATE_STOP :
                    (state == STATE_STOP & stop_done)                      ? STATE_IDLE :
                    (state == STATE_STOP & ~stop_done)                     ? STATE_STOP :
                    (state == STATE_ERROR)                                 ? STATE_IDLE : STATE_IDLE;
                    
always@(*) begin
    bit_count_next = bit_count_reg;        
    case(state)
            STATE_IDLE: begin
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 1'b0;
                addr_sent           = 1'b0;
                ack_o               = 1'b0;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                repeated_start_done = 1'b0;
                stop_done           = 1'b0;
                data_len_reg        = data_lenght;
            end /* End of idle state */
            
            STATE_START: begin
                start_bit      = 1'b1;
                ack_o          = 1'b1;
                bit_count_next = 5'd0;
            end /* End of start state */
            
            STATE_DEVICE_ADDR: begin
                repeated_start_done = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b1;
                bit_count_next = bit_count_reg + 1;
                if(bit_count_reg == 16) begin
                    byte_sent  = 1'b1;
                    read_ack   = 1'b1;
                    send_addr  = 1'b0;
                end
            end /* End of device address state */
            
            STATE_DEVICE_ADDR_ACK: begin
                sda_t          = 1'b1;
                read_ack       = 1'b0;
                byte_sent      = 1'b0;
                bit_count_next = 5'd0;
            end /* End of device address ack state */
            
            STATE_REGISTER_ADDR: begin
                send_addr      = 1'b1;
                bit_count_next = bit_count_reg + 1;
                if(bit_count_reg == 1) begin
                    sda_t      = 1'b0;
                end
                if(bit_count_reg == 16) begin
                    send_addr  = 1'b0;
                    addr_sent  = 1'b1;
                    byte_sent  = 1'b1;
                    read_ack   = 1'b1;
                end
            end /* End of register address state */  
            
            STATE_REGISTER_ADDR_ACK: begin
                sda_t          = 1'b1;
                read_ack       = 1'b0;
                byte_sent      = 1'b0;
                bit_count_next = 5'd0;
            end /* End of register address ack state */ 
            
            STATE_REPEATED_START: begin
                repeated_start = 1'b1;
                bit_count_next = bit_count_reg + 1;
                if(bit_count_reg == 1) begin
                    start_bit           = 1'b1;
                    repeated_start      = 1'b0;
                    sda_t               = 1'b0;
                    repeated_start_done = 1'b1;
                    bit_count_next      = 5'd0;
                end
            end /* End of repeated start state */ 
            
            STATE_READ: begin
                read_data      = 1'b1;
                bit_count_next = bit_count_reg + 1;
                if(bit_count_reg == 16) begin
                    read_data     = 1'b0;
                    send_ack      = 1'b1;
                    ack_o         = 1'b0;
                    data_received = 1'b1;
                end
            end /* End of read state */  
            
            STATE_READ_ACK: begin
                bit_count_next = 5'd0;
                send_ack       = 1'b0;
                sda_t          = 1'b0;
            end /* End of read ack state */     
            
            STATE_WRITE: begin
                send_data      = 1'b1;
                bit_count_next = bit_count_reg + 1;
                if(bit_count_reg == 1) begin
                    sda_t      = 1'b0;
                end
                if(bit_count_reg == 16) begin
                    byte_sent    = 1'b1;
                    read_ack     = 1'b1;
                    send_data    = 1'b0;
                    data_len_reg = data_len_reg - 1;
                end
            end /* End of write state */       
            
            STATE_WRITE_ACK: begin
                sda_t          = 1'b1;
                read_ack       = 1'b0;
                byte_sent      = 1'b0;
                bit_count_next = 5'd0;
                if(data_len_reg == 0) begin
                    data_sent = 1'b1;
                end
            end /* End of write ack state */
            
            STATE_STOP: begin
                bit_count_next = bit_count_reg + 1;
                ack_o    = 1'b1;
                if(bit_count_reg == 1) begin
                    sda_t     = 1'b0;
                    stop_done = 1'b1;
                    stop_bit  = 1'b1;
                end
            end /* End of stop state */
            
            default: begin
            end
    endcase
end          


endmodule

