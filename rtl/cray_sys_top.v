//////////////////////////////////////////////////////////////////
//        Cray System Top-level                                 //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the top-level file that actually gets instantiated 
//into the FPGA. It contains the actual Cray-1 CPU block, 
//4 kilowords of RAM, a UART, and the system clock-divider.
//
/////////////////////////
//    Memory Map       //
/////////////////////////
//
// System RAM:  0x000000-0x000FFF 
// UART Tx Busy:0x080000   (READ ONLY)
// UART Rx Rdy: 0x080001   (READ ONLY)
// UART Rx Data:0x080002   (If you read this address)
// UART Rx Clr: 0x080002   (If you write this address)
// UART Tx Data:0x080003   (WRITE ONLY)
//
module cray_sys_top(clk,
                    rst,
						  clk_rst,
						  tx_out,
						  rx_in,
						  o_led);
   

input  wire  clk;
input  wire  clk_rst;
input  wire  rst;
output wire  tx_out;
input  wire  rx_in;
output wire  o_led;

localparam MEM_WIDTH     = 4096;
localparam LOG_MEM_WIDTH = 12;

wire        rx_data_rdy; 
wire [63:0] rx_data;
wire        rd_clr; 
wire        tx_start;
wire        tx_busy;

wire [21:0] mem_addr;
wire [63:0] mem_wr_data;
reg  [63:0] mem_rd_data;
wire        mem_wr_en;
wire        mem_ce;

reg  [63:0] ram_data;
reg  [23:0] sys_clk;
reg         mem_vld;
reg  [63:0] ram [MEM_WIDTH-1:0];  


//////////////////////////////////
//      Cray-1A CPU             //
//////////////////////////////////
cray_top cray(
              //.clk(sys_clk[0]),
              .clk(clk),
              .rst(rst),
				  .o_mem_addr(mem_addr),
				  .o_mem_wr_data(mem_wr_data),
				  .i_mem_rd_data(mem_rd_data),
				  .i_mem_vld(mem_vld),
				  .o_mem_wr_en(mem_wr_en),
				  .o_mem_ce(mem_ce));
					 

assign o_led = 1'b0;

///////////////////////////////////
//        Serial Port            //
///////////////////////////////////

uart64 serport(.clk(clk),
             .rst(rst),
             .enable_read(rd_clr),          
             .enable_write(tx_start),  
             .data_in(mem_wr_data),             
             .data_out(rx_data),              
             .uart_read(rx_in),             
             .uart_write(tx_out),           
             .busy_write(tx_busy),            
             .data_avail(rx_data_rdy));          

					 
assign tx_start = mem_wr_en && (mem_addr[21:0]==22'b0010000000000000000011) && !tx_busy;     //located @ 0x080003
assign rd_clr   = mem_wr_en && (mem_addr[21:0]==22'b0010000000000000000010) && rx_data_rdy;  //located @ 0x080002


///////////////////////////////
//      System RAM           //
///////////////////////////////
//The system has 4 kilowords (32 kilobytes)
//of RAM that gets pre-initialized with the 
//contents of cray_rom.txt (a text file
//in hexadecimal format).

//make sure to only start a new transaction if the previous one is done
//always@(posedge sys_clk[0])
always@(posedge clk)
   mem_vld <= mem_ce;
	
	
//always@(posedge sys_clk[0])
always@(posedge clk)
   ram_data <= ram[mem_addr[LOG_MEM_WIDTH-1:0]];

initial $readmemh("cray_rom.txt",ram);

//always@(posedge sys_clk[0])
always@(posedge clk)
   if(mem_wr_en && (mem_addr[21:0]!=22'b0010000000000000000000))
	   ram[mem_addr[LOG_MEM_WIDTH-1:0]] <= mem_wr_data;

always@*
   begin
	   case(mem_addr[21:19])
		   3'b000: mem_rd_data = ram_data;
			3'b001:case(mem_addr[1:0])
						2'b00:mem_rd_data = {63'b0,tx_busy};			 //located @ 0x080000
						2'b01:mem_rd_data = {63'b0,rx_data_rdy};		 //located @ 0x080001
						2'b10:mem_rd_data = rx_data;	                //located @ 0x080002 
						2'b11:mem_rd_data = 64'b0;                    //located @ 0x080003
                endcase			
			default:mem_rd_data= 64'b0;
		endcase
	end


endmodule
