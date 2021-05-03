/////////////////////////////////////
//       64-bit UART               //
/////////////////////////////////////
// Uart that sends/receives data only
// in 8-byte chunks

module uart64(clk,
              rst,
				  enable_read,
				  enable_write,
				  data_in,
				  data_out,
				  uart_read,
				  uart_write,
				  busy_write,
				  data_avail);

input  wire clk;
input  wire rst;
input  wire enable_read;
input  wire enable_write;
input  wire [63:0] data_in;
output reg [63:0] data_out;
input  wire uart_read;
output wire uart_write;
output wire busy_write;
output wire data_avail;

reg [1:0] tx_state;
reg [2:0] tx_count;
reg [1:0] rx_state;
reg [2:0] rx_count;

wire       tx_busy;
wire       uart_tx_enable;
reg [63:0] temp_tx_data;
reg [7:0]  uart_tx_data;
wire [7:0] uart_rx_data;

wire       uart_data_avail;
wire       uart_read_en;
///////////////////////////////////
//     Uart Transmit Controller  //
///////////////////////////////////
//This block is in charge of taking in
//a 64-bit word, choppint it into 8-bit
//chunks, and then sending all 8 chunks
//out the UART
localparam TX_IDLE = 2'b00,
           TX_SEND = 2'b01,
			  TX_WAIT = 2'b10,
			  TX_DONE = 2'b11;
			  
always@(posedge clk)
   if(rst)
	   tx_state <= TX_IDLE;
	else case(tx_state)
	   TX_IDLE:if(enable_write) tx_state <= TX_SEND;
		TX_SEND:tx_state <= TX_WAIT;
		TX_WAIT:if(!tx_busy)
		           begin
					     if(tx_count==3'b111)
						     tx_state <= TX_DONE;
						  else
						     tx_state <= TX_SEND;
					  end
		TX_DONE:tx_state <= TX_IDLE;
	endcase
	
assign uart_tx_enable = (tx_state == TX_SEND);
assign busy_write = (tx_state != TX_IDLE);
	
always@(posedge clk)
   if (enable_write)
      temp_tx_data <= data_in;
	
always@(posedge clk)
   if(rst)
	   tx_count <= 3'b0;
	else if((tx_state==TX_WAIT) && tx_busy)
	   tx_count <= tx_count + 1;
	else if(tx_state==TX_DONE)
	   tx_count <= 3'b0;
		
always@*
   case(tx_count)
	   3'b000:uart_tx_data = temp_tx_data[7:0];
		3'b001:uart_tx_data = temp_tx_data[15:8];
		3'b010:uart_tx_data = temp_tx_data[23:16];
		3'b011:uart_tx_data = temp_tx_data[31:24];
		3'b100:uart_tx_data = temp_tx_data[39:32];
		3'b101:uart_tx_data = temp_tx_data[47:40];
		3'b110:uart_tx_data = temp_tx_data[55:48];
		3'b111:uart_tx_data = temp_tx_data[63:56];
	endcase
	
	
	
////////////////////////////////////
//      UART Receive Controller   //
////////////////////////////////////
//This block is responsible for 
//combining 8 8-bit chunks of data
//into one 64-bit chunk of data

localparam RX_IDLE    = 2'b00,
           RX_RECEIVE = 2'b01,
           RX_WAIT    = 2'b10,
			  RX_DONE    = 2'b11;

always@(posedge clk)
   if(rst)
		rx_state <= RX_IDLE;
	else case(rx_state)
		RX_IDLE: if(uart_data_avail) rx_state <= RX_RECEIVE;
		RX_RECEIVE:if(rx_count==3'b111) 
		              rx_state <= RX_DONE;
					  else
					     rx_state <= RX_WAIT;
		RX_WAIT:if(uart_data_avail)
		           rx_state <= RX_RECEIVE;
		RX_DONE:if(enable_read)
		           rx_state <= RX_IDLE;
	endcase
	
assign data_avail = (rx_state==RX_DONE);
	
always@(posedge clk)
   if(rst)
	   rx_count <= 3'b0;
	else if(rx_state==RX_RECEIVE)
	   rx_count <= rx_count + 1;
	else if(rx_state==RX_IDLE)
	   rx_count <= 3'b0;


always@(posedge clk)
   if(rst)
	   data_out <= 64'b0;
	else if(rx_state==RX_RECEIVE)
	   begin
			case(rx_count)
				3'b000:data_out[7:0]   <= uart_rx_data;
				3'b001:data_out[15:8]  <= uart_rx_data;
				3'b010:data_out[23:16] <= uart_rx_data;
				3'b011:data_out[31:24] <= uart_rx_data;
				3'b100:data_out[39:32] <= uart_rx_data;
				3'b101:data_out[47:40] <= uart_rx_data;
				3'b110:data_out[55:48] <= uart_rx_data;
				3'b111:data_out[63:56] <= uart_rx_data;
			endcase
		end
		
		
assign uart_read_en = (rx_state==RX_RECEIVE);

uart serport(.clk(clk),
             .reset(rst),
             .enable_read(uart_read_en),          
             .enable_write(uart_tx_enable),  
             .data_in(uart_tx_data),             
             .data_out(uart_rx_data),              
             .uart_read(uart_read),             
             .uart_write(uart_write),           
             .busy_write(tx_busy),            
             .data_avail(uart_data_avail)); 


endmodule
