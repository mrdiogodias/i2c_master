`timescale 1ns / 1ps


module i2c_master_cu(
    input  wire clk,
    input  wire rst,
    input  wire start_i2c,
    input  wire ack_i,
    input  wire rw, /* 0 -> Write; 1 -> Read */
    input  wire i2c_en,
    input  wire int_en, /* Flag to indicate if interrupt is enabled */
    input  wire [7:0]  data_lenght, /* Number of bytes to send */
    input  wire [15:0] prescaler,
 
    output reg  ack_o, 
    output reg  start_bit,
    output reg  stop_bit,
    output reg  send_addr,
    output reg  send_data,
    output reg  read_ack, 
    output reg  [1:0] repeated_start,
    output reg  send_ack,
    output reg  read_data,
    output reg  sda_t,
    output reg  valid_trans, /* 1 when tranmission is sucessful */
    output reg  valid_recep, /* 1 when reception   is sucessful */
    output wire error,
    output wire scl,
    output wire i2c_irq,
    output wire p_edge,
    output wire n_edge
);

localparam [3:0]  STATE_IDLE           = 4'd0,
                  STATE_START          = 4'd1,
                  STATE_ADDR           = 4'd2,
                  STATE_ADDR_ACK       = 4'd3,
                  STATE_REPEATED_START = 4'd4,
                  STATE_READ           = 4'd5, 
                  STATE_READ_ACK       = 4'd6,
                  STATE_WRITE          = 4'd7,
                  STATE_WRITE_ACK      = 4'd8,
                  STATE_STOP           = 4'd9,
                  STATE_ERROR          = 4'd10;
    
    
reg  [3:0] state;
wire [3:0] next_state;
reg data_received       = 1'b0;
reg data_sent           = 1'b0;
reg byte_sent           = 1'b0;
reg busy                = 1'b0;
reg [63:0] scl_counter  = 64'd0;
reg [3:0] bit_counter   = 4'd0;
reg rst_bit_counter     = 1'b1;
reg rs_counter          = 1'b0;
reg [7:0] data_len_reg  = 8'd0, data_len_next;
reg addr_sent_reg       = 1'b0, addr_sent_next;
reg scl_reg             = 1'b1;
reg scl_negedge         = 1'b0;
reg scl_posedge         = 1'b0;
reg valid_trans_next    = 1'b0;
reg valid_recep_next    = 1'b0;
initial valid_trans     = 1'b0;
initial valid_recep     = 1'b0;

assign error            = (state == STATE_ERROR) ? 1'b1 : 1'b0;
assign scl              = scl_reg;
assign p_edge           = scl_posedge;
assign n_edge           = scl_negedge;
/* If there is a valid transmission or a valid reception an interrutp should occur */
assign i2c_irq          = (int_en == 1'b1) ? (valid_trans | valid_recep) : 1'b0;

assign next_state = (state == STATE_IDLE & start_i2c)                                    ? STATE_START :
                    (state == STATE_IDLE & ~start_i2c)                                   ? STATE_IDLE : 
                    (state == STATE_START & scl_negedge)                                 ? STATE_ADDR :
                    (state == STATE_START & ~scl_negedge)                                ? STATE_START :
                    (state == STATE_ADDR & byte_sent)                                    ? STATE_ADDR_ACK :
                    (state == STATE_ADDR & ~byte_sent)                                   ? STATE_ADDR :
                    (state == STATE_ADDR_ACK & ~scl_negedge)                             ? STATE_ADDR_ACK :
                    (state == STATE_ADDR_ACK & ack_i & scl_negedge)                      ? STATE_ERROR :
                    (state == STATE_ADDR_ACK & ~ack_i & addr_sent_reg & scl_negedge)     ? STATE_READ :
                    (state == STATE_ADDR_ACK & ~ack_i & ~addr_sent_reg & scl_negedge)    ? STATE_WRITE :
                    (state == STATE_READ & data_received)                                ? STATE_READ_ACK :
                    (state == STATE_READ & ~data_received)                               ? STATE_READ :
                    (state == STATE_READ_ACK & ~scl_negedge)                             ? STATE_READ_ACK :
                    (state == STATE_READ_ACK & scl_negedge)                              ? STATE_STOP :
                    (state == STATE_WRITE & byte_sent)                                   ? STATE_WRITE_ACK :
                    (state == STATE_WRITE & ~byte_sent)                                  ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ~scl_negedge)                            ? STATE_WRITE_ACK :
                    (state == STATE_WRITE_ACK & ack_i & scl_negedge)                     ? STATE_ERROR :
                    (state == STATE_WRITE_ACK & ~ack_i & ~rw & ~data_sent & scl_negedge) ? STATE_WRITE :
                    (state == STATE_WRITE_ACK & ~ack_i & ~rw & data_sent & scl_negedge)  ? STATE_STOP :
                    (state == STATE_WRITE_ACK & ~ack_i & rw & scl_negedge)               ? STATE_REPEATED_START : 
                    (state == STATE_REPEATED_START & scl_negedge)                        ? STATE_ADDR :
                    (state == STATE_REPEATED_START & ~scl_negedge)                       ? STATE_REPEATED_START :
                    (state == STATE_STOP & scl_posedge)                                  ? STATE_IDLE :
                    (state == STATE_STOP & ~scl_posedge)                                 ? STATE_STOP :
                    (state == STATE_ERROR)                                               ? STATE_ERROR : STATE_ERROR;
     
/* Scl generator */
always@(posedge clk) begin
    if(!rst || !i2c_en) begin
        scl_reg     <= 1'b1;
        scl_counter <= 64'd0;
        scl_negedge <= 1'b0;
        scl_posedge <= 1'b0;
        rs_counter  <= 1'b0;
    end
    else begin
        if(scl_counter < prescaler & busy) begin
            scl_counter      <= scl_counter + 1'b1;
            scl_negedge      <= 1'b0;
            scl_posedge      <= 1'b0;
        end
        else if(scl_counter == prescaler & busy) begin
            scl_reg          <= ~scl_reg;
            scl_counter      <= 64'd0;
            scl_posedge      <= ~scl_reg;
            scl_negedge      <= scl_reg;
        end
        
        if(scl_counter >= (prescaler / 4) & busy & state == STATE_REPEATED_START & scl_reg == 1'b1) begin
            rs_counter <= 1'b1;
        end
        else begin
            rs_counter <= 1'b0;
        end
    end
end

always@(posedge clk) begin
    if(!rst || !i2c_en) begin
        state         <= STATE_IDLE;
    end
    else begin
        state         <= next_state;
        data_len_reg  <= data_len_next;
        addr_sent_reg <= addr_sent_next;
        valid_trans   <= valid_trans_next;
        valid_recep   <= valid_recep_next;
    end
end

always@(posedge clk) begin
    if(~rst || rst_bit_counter || !i2c_en) begin
        bit_counter <= 4'd0;
    end
    else if(scl_negedge) begin
        bit_counter <= bit_counter + 1'b1; 
    end
end     
                    
always@(*) begin 
    data_len_next                   = data_len_reg;  
    addr_sent_next                  = addr_sent_reg;
    valid_trans_next                = valid_trans;
    valid_recep_next                = valid_recep;
    
    case(state)
            STATE_IDLE: begin
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                addr_sent_next      = 1'b0;
                ack_o               = 1'b0;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                rst_bit_counter     = 1'b1;
                busy                = 1'b0;
                data_len_next       = data_lenght;
            end /* End of idle state */
            
            STATE_START: begin
                start_bit           = 1'b1;
                busy                = 1'b1;
                ack_o               = 1'b1;
                send_addr           = 1'b1;
                valid_trans_next    = 1'b0;
                valid_recep_next    = 1'b0;
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                rst_bit_counter     = 1'b1;
                repeated_start      = 2'd0;
            end /* End of start state */
            
            STATE_ADDR: begin
                start_bit           = 1'b0;
                
                if(bit_counter >= 7) begin
                    send_addr       = 1'b0;
                end
                else begin
                    send_addr       = 1'b1;
                end
                
                if(bit_counter > 7) begin
                    sda_t           = 1'b1;
                end 
                else begin
                    sda_t           = 1'b0;
                end
                      
                if(bit_counter > 7 & scl_posedge) begin
                    byte_sent       = 1'b1;
                    read_ack        = 1'b1;
                    rst_bit_counter = 1'b1;
                end
                else begin
                    byte_sent       = 1'b0;
                    read_ack        = 1'b0;
                    rst_bit_counter = 1'b0;
                end
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                send_data           = 1'b0;
                read_data           = 1'b0;
                send_ack            = 1'b0;
                ack_o               = 1'b1;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                busy                = 1'b1;
                repeated_start      = 2'd0;
            end /* End of device address state */
            
            STATE_ADDR_ACK: begin
                byte_sent           = 1'b0;
                read_ack            = 1'b1 & scl;
                sda_t               = rw ? 1'b1 : 1'b1 & scl;
                send_data           = ~addr_sent_reg;
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                ack_o               = 1'b1;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                rst_bit_counter     = 1'b1;
                busy                = 1'b1;
            end /* End of device address ack state */
            
            STATE_REPEATED_START: begin
                repeated_start[0]   = 1'b1;
                send_addr           = 1'b1;
                
                if(rs_counter) begin
                    repeated_start[1] = 1'b1;
                end
                else begin
                    repeated_start[1] = 1'b0;
                end
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                ack_o               = 1'b1;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                rst_bit_counter     = 1'b1;
                busy                = 1'b1;
            end /* End of repeated start state */ 
            
            STATE_READ: begin
                read_data           = 1'b1;
                rst_bit_counter     = 1'b0;
                
                if(bit_counter == 7 & scl_negedge) begin
                    data_received   = 1'b1;
                    ack_o           = 1'b1;
                    read_data       = 1'b0;
                    sda_t           = 1'b0;
                    send_ack        = 1'b1;
                end 
                else begin
                    data_received   = 1'b0;
                    ack_o           = 1'b1;
                    sda_t           = 1'b1;
                    read_data       = 1'b1;
                    send_ack        = 1'b0;
                end
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                repeated_start      = 2'd0;
                byte_sent           = 1'b0;
                data_sent           = 1'b0;
                busy                = 1'b1;
            end /* End of read state */  
            
            STATE_READ_ACK: begin
                send_ack            = 1'b1;
                ack_o               = 1'b1;
                data_received       = 1'b0;
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_sent           = 1'b0;
                rst_bit_counter     = 1'b1;
                busy                = 1'b1;
            end /* End of read ack state */     
            
            STATE_WRITE: begin
                addr_sent_next      = 1'b1;
                
                if(bit_counter >= 7) begin
                    send_data       = 1'b0;
                end
                else begin
                    send_data       = 1'b1;
                end
                
                if(bit_counter > 7) begin
                    sda_t           = 1'b1;
                end 
                else begin
                    sda_t           = 1'b0;
                end
                
                if(bit_counter > 7 & scl_posedge) begin
                    byte_sent       = 1'b1;
                    read_ack        = 1'b1;
                    rst_bit_counter = 1'b1;
                    data_len_next   = data_len_reg - 1;
                end
                else begin
                    byte_sent       = 1'b0;
                    read_ack        = 1'b0;
                    rst_bit_counter = 1'b0;
                end  
                
                /* Repeat the control signal values to avoid latches */
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                ack_o               = 1'b0;
                data_received       = 1'b0;
                data_sent           = 1'b0;
                busy                = 1'b1;
            end /* End of write state */       
            
            STATE_WRITE_ACK: begin
                byte_sent           = 1'b0;
                read_ack            = 1'b1 & scl;
                sda_t               = 1'b1 & scl;
                rst_bit_counter     = 1'b1;
                
                if(data_len_reg == 0) begin
                    data_sent       = 1'b1;
                    send_data       = 1'b0;
                    stop_bit        = 1'b1;
                end
                else begin 
                    data_sent       = 1'b0;
                    send_data       = ~rw;
                    stop_bit        = 1'b0;
                end
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                ack_o               = 1'b0;
                data_received       = 1'b0;
                busy                = 1'b1;
            end /* End of write ack state */
            
            STATE_STOP: begin
                stop_bit            = 1'b1;
                ack_o               = 1'b1;
                data_sent           = 1'b0;
                
                if(rw) begin
                    valid_recep_next = 1'b1;
                end 
                else begin
                    valid_trans_next = 1'b1;
                end
                
                /* Repeat the control signal values to avoid latches */
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_received       = 1'b0;
                rst_bit_counter     = 1'b1;
                busy                = 1'b1;
            end /* End of stop state */
            
            default: begin
                stop_bit            = 1'b0;
                start_bit           = 1'b0;
                send_addr           = 1'b0;
                send_data           = 1'b0;
                read_ack            = 1'b0; 
                read_data           = 1'b0;
                send_ack            = 1'b0;
                repeated_start      = 2'd0;
                addr_sent_next      = 1'b0;
                ack_o               = 1'b1;
                sda_t               = 1'b0;
                byte_sent           = 1'b0;
                data_sent           = 1'b0;
                data_received       = 1'b0;
                data_len_next       = data_lenght;
                busy                = 1'b0;
                rst_bit_counter     = 1'b1;
                valid_trans_next    = 1'b0;
                valid_recep_next    = 1'b0;
            end
    endcase
end          

endmodule
