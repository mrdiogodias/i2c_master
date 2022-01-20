`timescale 1 ns / 1 ps


module i2c_master_axi_slave_v1_0_S00_AXI #(
    // Width of S_AXI data bus
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    // Width of S_AXI address bus
    parameter integer C_S_AXI_ADDR_WIDTH = 4,
    
    // Users to add parameters here
    parameter   OPT_LOWPOWER = 1'b0,
    localparam	ADDRLSB      = $clog2(C_S_AXI_DATA_WIDTH)-3
    // User parameters ends
)(
    // Users to add ports here
    inout   wire sda,
    output  wire scl,
    output  wire i2c_irq,
    // User ports ends
    
    // Do not modify the ports beyond this line
    input	wire S_AXI_ACLK,
    input	wire S_AXI_ARESETN,
    
    input	wire S_AXI_AWVALID,
    output	wire S_AXI_AWREADY,
    input	wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_AWADDR,
    input	wire [2:0] S_AXI_AWPROT,
    
    input	wire S_AXI_WVALID,
    output	wire S_AXI_WREADY,
    input	wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_WDATA,
    input	wire [C_S_AXI_DATA_WIDTH/8-1:0] S_AXI_WSTRB,
    
    output	wire S_AXI_BVALID,
    input	wire S_AXI_BREADY,
    output	wire [1:0] S_AXI_BRESP,
    
    input	wire S_AXI_ARVALID,
    output	wire S_AXI_ARREADY,
    input	wire [C_S_AXI_ADDR_WIDTH-1:0] S_AXI_ARADDR,
    input	wire [2:0] S_AXI_ARPROT,
    
    output	wire S_AXI_RVALID,
    input	wire S_AXI_RREADY,
    output	wire [C_S_AXI_DATA_WIDTH-1:0] S_AXI_RDATA,
    output	wire [1:0] S_AXI_RRESP
);


/***********************************************************************
 *
 * Register/wire signal declarations
 * 
 ***********************************************************************/

wire [C_S_AXI_ADDR_WIDTH-ADDRLSB-1:0] awskd_addr;
wire [C_S_AXI_DATA_WIDTH-1:0]	      wskd_data;
wire [C_S_AXI_DATA_WIDTH/8-1:0]	      wskd_strb;
wire [C_S_AXI_ADDR_WIDTH-ADDRLSB-1:0] arskd_addr;
reg	 [C_S_AXI_DATA_WIDTH-1:0]	      axil_read_data = 0;
wire axil_write_ready;
wire axil_read_ready;
reg	 axil_bvalid     = 1'b0;
reg	 axil_read_valid = 1'b0;

reg	 [31:0]	i2c_conf_reg0   = 1'b0;
reg	 [31:0]	i2c_conf_reg1   = 1'b0;
reg	 [31:0]	i2c_conf_reg2   = 1'b0;
reg	 [31:0]	i2c_conf_reg3   = 1'b0;

wire [31:0] i2c_conf_wire0; 
wire error;
wire valid_trans;
wire valid_recep;

assign i2c_conf_wire0[8:0]   = i2c_conf_reg0[8:0];
assign i2c_conf_wire0[9]     = error;
assign i2c_conf_wire0[10]    = valid_trans;
assign i2c_conf_wire0[11]    = valid_recep;
assign i2c_conf_wire0[12]    = i2c_conf_reg0[12];
assign i2c_conf_wire0[13]    = i2c_conf_reg0[13];
assign i2c_conf_wire0[15:14] = 2'b00;
assign i2c_conf_wire0[31:16] = i2c_conf_reg0[31:16];

wire [31:0] i2c_conf_wire3; 
wire [7:0]  data_received;

assign i2c_conf_wire3[31:16] = i2c_conf_reg3[31:16];
assign i2c_conf_wire3[15:0]  = {data_received, 8'd0};

wire [31:0]	wskd_i2c_conf_reg0;
wire [31:0]	wskd_i2c_conf_reg1;
wire [31:0]	wskd_i2c_conf_reg2;
wire [31:0]	wskd_i2c_conf_reg3;

/***********************************************************************
 *
 * AXI-Lite signaling
 * 
 ***********************************************************************/

/****** Write signaling *****/

reg axil_awready = 1'b0;

always @(posedge S_AXI_ACLK) begin
    if(!S_AXI_ARESETN) begin
        axil_awready <= 1'b0;
    end
    else begin
        axil_awready <= !axil_awready && (S_AXI_AWVALID && S_AXI_WVALID) && (!S_AXI_BVALID || S_AXI_BREADY);
    end
end

assign S_AXI_AWREADY    = axil_awready;
assign S_AXI_WREADY     = axil_awready;
assign awskd_addr       = S_AXI_AWADDR[C_S_AXI_ADDR_WIDTH-1:ADDRLSB];
assign wskd_data        = S_AXI_WDATA;
assign wskd_strb        = S_AXI_WSTRB;
assign axil_write_ready = axil_awready;


always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axil_bvalid <= 1'b0;
    end
    else if (axil_write_ready) begin
        axil_bvalid <= 1'b1;
    end
    else if (S_AXI_BREADY) begin
        axil_bvalid <= 1'b0;
    end
end

assign S_AXI_BVALID = axil_bvalid;
assign S_AXI_BRESP  = 2'b00;


/****** Read signaling *****/

reg	axil_arready;

always @(*) begin
    axil_arready = !S_AXI_RVALID;
end

assign arskd_addr      = S_AXI_ARADDR[C_S_AXI_ADDR_WIDTH-1:ADDRLSB];
assign S_AXI_ARREADY   = axil_arready;
assign axil_read_ready = (S_AXI_ARVALID && S_AXI_ARREADY);


always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        axil_read_valid <= 1'b0;
    end
    else if (axil_read_ready) begin
        axil_read_valid <= 1'b1;
    end
    else if (S_AXI_RREADY) begin
        axil_read_valid <= 1'b0;
    end
end

assign S_AXI_RVALID = axil_read_valid;
assign S_AXI_RDATA  = axil_read_data;
assign S_AXI_RRESP  = 2'b00;


/***********************************************************************
 *
 * AXI-Lite register logic
 * 
 ***********************************************************************/

assign wskd_i2c_conf_reg0 = apply_wstrb(i2c_conf_reg0, wskd_data, wskd_strb);
assign wskd_i2c_conf_reg1 = apply_wstrb(i2c_conf_reg1, wskd_data, wskd_strb);
assign wskd_i2c_conf_reg2 = apply_wstrb(i2c_conf_reg2, wskd_data, wskd_strb);
assign wskd_i2c_conf_reg3 = apply_wstrb(i2c_conf_reg3, wskd_data, wskd_strb);

always @(posedge S_AXI_ACLK) begin
    if (!S_AXI_ARESETN) begin
        i2c_conf_reg0 <= 32'd0;
        i2c_conf_reg1 <= 32'd0;
        i2c_conf_reg2 <= 32'd0;
        i2c_conf_reg3 <= 32'd0;
    end 
    else begin 
        if (axil_write_ready) begin
            case(awskd_addr)
                2'b00:	i2c_conf_reg0 <= wskd_i2c_conf_reg0;
                2'b01:	i2c_conf_reg1 <= wskd_i2c_conf_reg1;
                2'b10:	i2c_conf_reg2 <= wskd_i2c_conf_reg2;
                2'b11:	i2c_conf_reg3 <= wskd_i2c_conf_reg3;
            endcase
        end
        else begin
            /* Clear start bit */
            i2c_conf_reg0[8] <= 1'b0;
        end
    end
end

always @(posedge S_AXI_ACLK) begin
    if (OPT_LOWPOWER && !S_AXI_ARESETN) begin
        axil_read_data <= 0;
    end
    else if (!S_AXI_RVALID || S_AXI_RREADY) begin
        case(arskd_addr)
            2'b00:	axil_read_data <= i2c_conf_wire0;
            2'b01:	axil_read_data <= i2c_conf_reg1;
            2'b10:	axil_read_data <= i2c_conf_reg2;
            2'b11:	axil_read_data <= i2c_conf_wire3;
        endcase
    
        if (OPT_LOWPOWER && !axil_read_ready) begin
            axil_read_data <= 0;
        end
    end
end

function  [C_S_AXI_DATA_WIDTH-1:0]	 apply_wstrb;

    input [C_S_AXI_DATA_WIDTH-1:0]   prior_data;
    input [C_S_AXI_DATA_WIDTH-1:0]   new_data;
    input [C_S_AXI_DATA_WIDTH/8-1:0] wstrb;

    integer	k;
    for(k = 0; k < C_S_AXI_DATA_WIDTH/8; k = k + 1) begin
        apply_wstrb[k*8 +: 8] = wstrb[k] ? new_data[k*8 +: 8] : prior_data[k*8 +: 8];
    end
endfunction


/***********************************************************************
 *
 * I2C Master
 * 
 ***********************************************************************/

i2c_master i2c_unit(
    .clk(S_AXI_ACLK), 
    .rst(S_AXI_ARESETN), 
    .start_i2c(i2c_conf_reg0[8]),
    .i2c_en(i2c_conf_reg0[12]),
    .int_en(i2c_conf_reg0[13]),
    .addr(i2c_conf_reg0[7:0]),
    .prescaler(i2c_conf_reg0[31:16]),
    .data_to_send({i2c_conf_reg1, i2c_conf_reg2, i2c_conf_reg3[31:24]}),
    .data_size(i2c_conf_reg3[23:16]),
    .data_received(data_received),
    .error(error), 
    .sda(sda), 
    .scl(scl),
    .valid_trans(valid_trans),
    .valid_recep(valid_recep),
    .i2c_irq(i2c_irq)
);

endmodule

