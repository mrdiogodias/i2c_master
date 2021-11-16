`timescale 1ns / 1ps


module i2c_master_cu(
    input  wire clk,
    input  wire rst,
    input  wire valid_cmd,
    
    input  wire ack_i,
    input  wire rw, /* 0 -> Write; 1 -> Read */
    input  wire [7:0] data_lenght, /* Number of bytes to send */
 
    output reg  ack_o, 
    output reg  start_bit,
    output reg  stop_bit,
    output reg  send_addr,
    output reg  send_data,
    output reg  read_ack, 
    output reg  repeated_start,
    output reg  send_ack,
    output reg  read_data,
    output wire [3:0] error,
    output reg  sda_t
);

localparam [3:0] PRESCALER  = 4'd2;
localparam [3:0]
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
    
    
reg  [3:0] state;
wire [3:0] next_state;

reg data_received       = 1'b0;
reg data_sent           = 1'b0;
reg byte_sent           = 1'b0;
reg repeated_start_done = 1'b0;
reg stop_done           = 1'b0;
reg [4:0] bit_count_reg = 5'd0, bit_count_next;
reg [7:0] data_len_reg  = 8'd0, data_len_next;
reg addr_sent_reg       = 1'b0, addr_sent_next;

assign error = state; /* Debug purposes */

always@(posedge clk) begin
    if(!rst) begin
        state         <= STATE_IDLE;
    end
    else begin
        state         <= next_state;
        bit_count_reg <= bit_count_next;
        data_len_reg  <= data_len_next;
        addr_sent_reg <= addr_sent_next;
    end
end

assign next_state = (state == STATE_IDLE & valid_cmd)                          ? STATE_START :
                    (state == STATE_IDLE & ~valid_cmd)                         ? STATE_IDLE : 
                    (state == STATE_START)                                     ? STATE_DEVICE_ADDR:
                    (state == STATE_DEVICE_ADDR & byte_sent)                   ? STATE_DEVICE_ADDR_ACK:
                    (state == STATE_DEVICE_ADDR & ~byte_sent)                  ? STATE_DEVICE_ADDR:
                    (state == STATE_DEVICE_ADDR_ACK & ack_i)                   ? STATE_ERROR:
                    (state == STATE_DEVICE_ADDR_ACK & ~ack_i & addr_sent_reg)  ? STATE_READ:
                    (state == STATE_DEVICE_ADDR_ACK & ~ack_i & ~addr_sent_reg) ? STATE_REGISTER_ADDR:
                    (state == STATE_REGISTER_ADDR & byte_sent)                 ? STATE_REGISTER_ADDR_ACK :
                    (state == STATE_REGISTER_ADDR & ~byte_sent)                ? STATE_REGISTER_ADDR :
                    (state == STATE_REGISTER_ADDR_ACK & ack_i)                 ? STATE_ERROR :
                    (state == STATE_REGISTER_ADDR_ACK & ~ack_i & rw)           ? STATE_REPEATED_START :
                    (state == STATE_REGISTER_ADDR_ACK & ~ack_i & ~rw)          ? STATE_WRITE :
                    (state == STATE_REPEATED_START & ~repeated_start_done)     ? STATE_REPEATED_START:
                    (state == STATE_REPEATED_START & repeated_start_done)      ? STATE_DEVICE_ADDR:
                    (state == STATE_READ & data_received)                      ? STATE_READ_ACK:
                    (state == STATE_READ & ~data_received)                     ? STATE_READ:
                    (state == STATE_READ_ACK & ack_o)                          ? STATE_ERROR :
                    (state == STATE_READ_ACK & ~ack_o)                         ? STATE_STOP :
                    (state == STATE_WRITE & byte_sent)                         ? STATE_WRITE_ACK :
                    (state == STATE_WRITE & ~byte_sent)                        ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ack_i)                         ? STATE_ERROR :
                    (state == STATE_WRITE_ACK & ~ack_i & ~data_sent)           ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ~ack_i & data_sent)            ? STATE_STOP :
                    (state == STATE_STOP & stop_done)                          ? STATE_IDLE :
                    (state == STATE_STOP & ~stop_done)                         ? STATE_STOP :
                    (state == STATE_ERROR)                                     ? STATE_IDLE : STATE_IDLE;
                    
always@(*) begin
    bit_count_next                  = bit_count_reg;     
    data_len_next                   = data_len_reg;  
    addr_sent_next                  = addr_sent_reg;
    
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
                addr_sent_next      = 1'b0;
                ack_o               = 1'b1;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                repeated_start_done = 1'b0;
                stop_done           = 1'b0;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                data_len_next       = data_lenght;
            end /* End of idle state */
            
            STATE_START: begin
                start_bit           = 1'b1;
                bit_count_next      = 5'd0;
                
                /* Repeat the control signal values to avoid latches */
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                read_ack            = 1'b0;
                repeated_start      = 1'b0;
                byte_sent           = 1'b0;
                send_data           = 1'b0;
                sda_t               = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of start state */
            
            STATE_DEVICE_ADDR: begin
                repeated_start_done = 1'b0;
                start_bit           = 1'b0;
                bit_count_next      = bit_count_reg + 1;
                
                /* 1 byte sent ? (device addr)*/
                if(bit_count_reg == PRESCALER * 8) begin
                    byte_sent       = 1'b1;
                    read_ack        = 1'b1;
                    send_addr       = 1'b0;
                end
                else begin
                    read_ack        = 1'b0;
                    byte_sent       = 1'b0;
                    send_addr       = 1'b1;
                end
                
                /* Repeat the control signal values to avoid latches */
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start      = 1'b0;
                send_data           = 1'b0;
                sda_t               = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
            end /* End of device address state */
            
            STATE_DEVICE_ADDR_ACK: begin
                sda_t               = 1'b1;
                read_ack            = 1'b0;
                byte_sent           = 1'b0;
                bit_count_next      = 5'd0;
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                repeated_start      = 1'b0;
                send_data           = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of device address ack state */
            
            STATE_REGISTER_ADDR: begin
                bit_count_next      = bit_count_reg + 1;
                
                /* Turn off sda_t after the 2nd clock in this state */
                if(bit_count_reg >= 1) begin
                    sda_t           = 1'b0;
                end
                else begin
                    sda_t           = 1'b1;
                end
                
                /* 1 byte sent ? (register addr) */
                if(bit_count_reg == PRESCALER * 8) begin
                    send_addr       = 1'b0;
                    addr_sent_next  = 1'b1;
                    byte_sent       = 1'b1;
                    read_ack        = 1'b1;
                end
                else begin
                    read_ack        = 1'b0;
                    byte_sent       = 1'b0;
                    send_addr       = 1'b1;
                end
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                repeated_start      = 1'b0;
                send_data           = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
            end /* End of register address state */  
            
            STATE_REGISTER_ADDR_ACK: begin
                sda_t               = 1'b1;
                read_ack            = 1'b0;
                byte_sent           = 1'b0;
                bit_count_next      = 5'd0;
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                repeated_start      = 1'b0;
                send_data           = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of register address ack state */ 
            
            STATE_REPEATED_START: begin
                bit_count_next          = bit_count_reg + 1;
                
                if(bit_count_reg == 1) begin
                    start_bit           = 1'b1;
                    repeated_start      = 1'b0;
                    sda_t               = 1'b0;
                    repeated_start_done = 1'b1;
                    bit_count_next      = 5'd0;
                end
                else begin
                    start_bit           = 1'b0;
                    repeated_start_done = 1'b0;
                    repeated_start      = 1'b1;
                    sda_t               = 1'b1;
                end
                
                /* Repeat the control signal values to avoid latches */
                ack_o                   = 1'b1;
                stop_bit                = 1'b0;
                stop_done               = 1'b0;
                data_sent               = 1'b0;
                data_received           = 1'b0;
                read_ack                = 1'b0;
                byte_sent               = 1'b0;
                send_data               = 1'b0;
                send_ack                = 1'b0;
                read_data               = 1'b0;
                send_addr               = 1'b0;
            end /* End of repeated start state */ 
            
            STATE_READ: begin
                bit_count_next      = bit_count_reg + 1;
                
                /* 1 byte read ?*/
                if(bit_count_reg == PRESCALER * 8) begin
                    read_data       = 1'b0;
                    send_ack        = 1'b1;
                    ack_o           = 1'b0; /* Always sucess for debug purposes */
                    data_received   = 1'b1;
                end
                else begin
                    read_data       = 1'b1;
                    ack_o           = 1'b1;
                    data_received   = 1'b0;
                    send_ack        = 1'b0;
                end
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                repeated_start_done = 1'b0;
                read_ack            = 1'b0;
                repeated_start      = 1'b0;
                byte_sent           = 1'b0;
                send_data           = 1'b0;
                sda_t               = 1'b1;
                send_addr           = 1'b0;
            end /* End of read state */  
            
            STATE_READ_ACK: begin
                bit_count_next     = 5'd0;
                send_ack           = 1'b0;
                sda_t              = 1'b0;
                
                /* Repeat the control signal values to avoid latches */
                ack_o               = 1'b0;
                start_bit           = 1'b0;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                read_ack            = 1'b0;
                repeated_start      = 1'b0;
                byte_sent           = 1'b0;
                send_data           = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of read ack state */     
            
            STATE_WRITE: begin
                bit_count_next      = bit_count_reg + 1;
                
                /* Turn off sda_t after the 2nd clock in this state */
                if(bit_count_reg >= 1) begin
                    sda_t           = 1'b0;
                end
                else begin
                    sda_t           = 1'b1;
                end
                
                /* 1 byte sent ? (data) */
                if(bit_count_reg == PRESCALER * 8) begin
                    byte_sent       = 1'b1;
                    read_ack        = 1'b1;
                    send_data       = 1'b0;
                    data_len_next   = data_len_reg - 1;
                end
                else begin
                    read_ack        = 1'b0;
                    byte_sent       = 1'b0;
                    send_data       = 1'b1;
                end
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                repeated_start      = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of write state */       
            
            STATE_WRITE_ACK: begin
                sda_t               = 1'b1;
                read_ack            = 1'b0;
                byte_sent           = 1'b0;
                bit_count_next      = 5'd0;
                
                /* All data bytes sent ? */
                if(data_len_reg == 0) begin
                    data_sent       = 1'b1;
                end
                else begin 
                    data_sent       = 1'b0;
                end
                
                /* Turn off sda_t after the 2nd clock in this state */
                start_bit           = 1'b0;
                ack_o               = 1'b1;
                stop_bit            = 1'b0;
                stop_done           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                repeated_start      = 1'b0;
                send_data           = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of write ack state */
            
            STATE_STOP: begin
                bit_count_next      = bit_count_reg + 1;
                ack_o               = 1'b1;
                
                if(bit_count_reg == 1) begin
                    sda_t           = 1'b0;
                    stop_done       = 1'b1;
                    stop_bit        = 1'b1;
                end
                else begin  
                    stop_bit        = 1'b0;
                    stop_done       = 1'b0;
                    sda_t           = 1'b1;
                end
                
                /* Turn off sda_t after the 2nd clock in this state */
                start_bit           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                repeated_start_done = 1'b0;
                read_ack            = 1'b0;
                repeated_start      = 1'b0;
                byte_sent           = 1'b0;
                send_data           = 1'b0;
                send_ack            = 1'b0;
                read_data           = 1'b0;
                send_addr           = 1'b0;
            end /* End of stop state */
            
            default: begin
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 1'b0;
                addr_sent_next      = 1'b0;
                ack_o               = 1'b1;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                repeated_start_done = 1'b0;
                stop_done           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                data_len_next       = data_lenght;
            end
    endcase
end          

endmodule
