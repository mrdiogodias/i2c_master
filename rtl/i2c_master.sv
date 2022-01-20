`timescale 1ns / 1ps


module i2c_master #(
    parameter DATA_WIDTH = 9 /* Max number of bytes that can be sent in each write operation */
)(
    input  wire clk,
    input  wire rst,
    input  wire start_i2c,
    input  wire i2c_en,
    input  wire int_en,
    input  wire [7:0] addr, /* Slave addr */ 
    input  wire [(DATA_WIDTH * 8)-1:0] data_to_send, /* 1st byte is the reg addr */
    input  wire [7:0] data_size,
    input  wire [15:0] prescaler, /* Tscl = (Tclk * 2 * PRESCALER) + (2 * Tclk) */
    
    output wire [7:0] data_received,
    output wire valid_trans, /* 1 when tranmission is sucessful */
    output wire valid_recep, /* 1 when reception   is sucessful */
    output wire error,
    inout  wire sda,
    output wire scl,
    output wire i2c_irq
);


wire cu_ack; /* ack from cu to dp (from I2C master to I2C slave) */
wire dp_ack; /* ack from dp to cu (from I2C slave to I2C master) */
wire start_bit;
wire stop_bit;
wire send_addr;
wire send_data;
wire read_ack;
wire send_ack;
wire read_data;
wire [1:0] repeated_start;
wire scl_posedge; 
wire scl_negedge;
wire sda_i;
wire sda_o;
wire sda_t;


IOBUF #(
    .DRIVE(12),             // Specify the output drive strength
    .IBUF_LOW_PWR("TRUE"),  // Low Power - "TRUE", High Performance = "FALSE" 
    .IOSTANDARD("DEFAULT"), // Specify the I/O standard
    .SLEW("SLOW")           // Specify the output slew rate
) IOBUF_inst(
    .O(sda_i),              // Buffer output
    .IO(sda),               // Buffer inout port (connect directly to top-level port)
    .I(sda_o),              // Buffer input
    .T(sda_t)               // 3-state enable input, high=input, low=output
    ); 

i2c_master_dp #(
    .DATA_WIDTH(DATA_WIDTH)
) 
datapath (
    .clk(clk),
    .rst(rst), 
    .addr(addr), 
    .data_to_send(data_to_send),
    .data_received(data_received),
    .start_bit(start_bit),
    .stop_bit(stop_bit),
    .send_addr(send_addr),
    .send_data(send_data),
    .read_ack(read_ack), 
    .send_ack(send_ack),
    .read_data(read_data),
    .repeated_start(repeated_start),
    .ack_o(dp_ack),
    .ack_i(cu_ack),
    .scl(scl),
    .p_edge(scl_posedge),
    .n_edge(scl_negedge),
    .sda_i(sda_i), 
    .sda_o(sda_o)
);

i2c_master_cu control_unit(
    .clk(clk),
    .rst(rst),
    .start_i2c(start_i2c),
    .ack_i(dp_ack),
    .rw(addr[0]),
    .i2c_en(i2c_en),
    .int_en(int_en),
    .data_lenght(data_size), 
    .prescaler(prescaler), 
    .ack_o(cu_ack),
    .start_bit(start_bit),
    .stop_bit(stop_bit),
    .repeated_start(repeated_start),
    .send_addr(send_addr),
    .send_data(send_data),
    .read_ack(read_ack), 
    .send_ack(send_ack),
    .read_data(read_data),
    .error(error),
    .sda_t(sda_t),
    .scl(scl),
    .p_edge(scl_posedge),
    .n_edge(scl_negedge),
    .valid_trans(valid_trans),
    .valid_recep(valid_recep),
    .i2c_irq(i2c_irq)
);

endmodule
