//////////////////////////////////////////////////////////////////
//        Vector Register File                                  //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains one 64 entry, 64-bit register file used
//for each of the Cray-1A's 8 vector registers

module vec_regfile_hard (clk,
						  rst,
						o_rd_data,
						i_sbus,
						i_v_add,
						i_v_log,
						i_v_shift,
						i_v_poppar,
						i_fp_add,
						i_fp_mult,
						i_fp_ra,
						i_mem,
                  i_vread_start,
						i_vwrite_start,
						i_swrite_start,
						i_vector_length,
						i_vector_mask,
						i_ak,
						i_fu_time,
						i_fu,
						o_busy,
						o_chain_n);

parameter WIDTH = 64;
parameter DEPTH = 64;
parameter LOGDEPTH = 6;


input  wire                clk;
input  wire                rst;
output reg  [WIDTH-1:0]    o_rd_data;
input  wire [WIDTH-1:0]    i_sbus;
input  wire [WIDTH-1:0]    i_v_add;
input  wire [WIDTH-1:0]    i_v_log;
input  wire [WIDTH-1:0]    i_v_shift;
input  wire [WIDTH-1:0]    i_v_poppar;
input  wire [WIDTH-1:0]    i_fp_add;
input  wire [WIDTH-1:0]    i_fp_mult;
input  wire [WIDTH-1:0]    i_fp_ra;
input  wire [WIDTH-1:0]    i_mem;
input  wire                i_vread_start;
input  wire                i_vwrite_start;
input  wire                i_swrite_start;
input  wire [LOGDEPTH:0]   i_vector_length;
input  wire [WIDTH-1:0]    i_vector_mask;
input  wire [23:0]         i_ak;
input  wire [3:0]          i_fu_time;
input  wire [2:0]          i_fu;
output wire                o_busy;
output wire                o_chain_n;



reg [WIDTH-1:0] selected_data;
wire [WIDTH-1:0] data_to_be_written;
wire [WIDTH-1:0] data_to_be_read;
reg [WIDTH-1:0] data [DEPTH-1:0];     //the actual registers
reg [WIDTH-1:0] delay0, delay1, delay2;
reg [1:0] vec_state;

reg [LOGDEPTH-1:0] read_ptr;
reg [LOGDEPTH-1:0] write_ptr;
reg [LOGDEPTH:0]   cur_vector_length;
reg [LOGDEPTH:0]   cur_vector_length_minus_one;
reg [WIDTH-1:0]    cur_vector_mask;
reg [4:0]          write_delay;
reg [2:0]          cur_source;

wire long_vector; 
wire vtype;
wire stype;
wire write_enable;
wire final_write_enable;
wire [5:0] final_write_address;


localparam IDLE = 2'b00,
           READ = 2'b01,
			 WRITE = 2'b10,
		    CHAIN = 2'b11;

			
//Sources			   
localparam VLOG      = 3'b000,   //vector logical
           VSHIFT    = 3'b001,	 //vector shift
			  VADD      = 3'b010,
	        FP_MUL    = 3'b011,   //FP multiply
	        FP_ADD    = 3'b100,   //FP adder 
	        FP_RA     = 3'b101,   //FP recip. approx.
	        VPOP      = 3'b110,   //vector pop count / parity
	         MEM      = 3'b111;


assign o_busy = (vec_state != IDLE) && !((vec_state==WRITE) && ({1'b0,write_ptr}==cur_vector_length_minus_one));

assign o_chain_n = ~(write_delay==5'b00010);   //chain slot time is FU time + 2 CPs


assign long_vector = i_vector_length > 7'b0000100;
assign vtype = i_vread_start || i_vwrite_start;

assign write_enable = (((vec_state==WRITE) || (vec_state==CHAIN)) && (write_delay==5'b0) && ({1'b0,write_ptr} < cur_vector_length));

//just grab the current vector length and mask
always@(posedge clk)
   if(i_vread_start || i_vwrite_start)
	begin
	   cur_vector_length <= i_vector_length;
		cur_vector_length_minus_one <= i_vector_length - 1;
		cur_vector_mask   <= i_vector_mask;
	end

//Grab the source
always@(posedge clk)
   if(i_vwrite_start)
	   cur_source <= i_fu;

//Figure out which source we actually want to write from	
always@*
   case(cur_source)
	       VLOG: selected_data   = i_v_log;   //vector logical
          VSHIFT: selected_data = i_v_shift; //vector shift
			   VADD: selected_data = i_v_add;   //vector add
	       FP_MUL: selected_data = i_fp_mult;  //FP multiply
	       FP_ADD: selected_data = i_fp_add;  //FP adder 
	        FP_RA: selected_data = i_fp_ra;   //FP recip. approx.
	         VPOP: selected_data = i_v_poppar; //vector pop count / parity
	          MEM: selected_data = i_mem;      //memory
	endcase
		
assign data_to_be_written = i_swrite_start ? i_sbus : selected_data;

//Let's calculate the read pointer
always@(posedge clk)
	if(rst)
		read_ptr <= 6'b0;
   else if(i_vread_start)
	   read_ptr <= 6'b0;          //if it's a vector, start at 0, 
	else if (vec_state==READ)
	   read_ptr <= read_ptr + 6'b1;
	else
      read_ptr <= i_ak[5:0];     //if it's scalar, start at Ak

//and the write pointer

always@(posedge clk)
   if(rst)
	   write_ptr <= 6'b0;
   else if(i_vwrite_start)
	   write_ptr <= 6'b0;
   else if((vec_state==WRITE) | (vec_state==CHAIN))
	   if(write_delay==5'b0)
		   write_ptr <= write_ptr + 6'b1;


hard_v_reg vmem (
	.clka(clk),
	.wea((write_enable && cur_vector_mask[write_ptr]) || i_swrite_start), 
	.addra(i_swrite_start ? i_ak[5:0] : write_ptr), 
	.dina(data_to_be_written), 
	.clkb(clk),
	.rstb(rst),
	.addrb(read_ptr),
	.doutb(data_to_be_read)); // Bus [63 : 0] 

//read a register

//The vector registers have a 5-cycle read latency for some reason.
//I am not sure why, but for now I'm just implementing it with a simple delay for timing reasons.
always@(posedge clk)
   begin
	   delay0 <= data_to_be_read;
		delay1 <= delay0;
		o_rd_data <= (vec_state==CHAIN) ? selected_data : delay1;      //this properly re-directs the input during chain-slot time
		//o_rd_data <= delay2;
	end
	
//finally calculate the write delay
always@(posedge clk)
   if(rst)
	   write_delay <= 5'b0;
   else if(i_vwrite_start)
	   write_delay <= i_fu_time + 5'b00100;
	else if(write_delay != 5'b0)
	   write_delay <= write_delay - 5'b1;



/////////////////////
//   FSM           //
/////////////////////
//This is the finite state machine that controls
//the vector register
always@(posedge clk)
if(rst) vec_state <= IDLE;
else
   case(vec_state)
	   IDLE: begin
		         if(i_vread_start)
					   vec_state <= READ;
					else if(i_vwrite_start)
					   vec_state <= WRITE;
		      end
		READ: begin
		         if({1'b0,read_ptr}==(cur_vector_length - 7'b1))
					   vec_state <= IDLE;
		      end
		WRITE:begin
		         if(i_vread_start && ~({1'b0,write_ptr}==(cur_vector_length-7'b1)))
					   vec_state <= CHAIN;
					else if (i_vread_start && ({1'b0,write_ptr}==(cur_vector_length-7'b1)))
					   vec_state <= READ;
					else if ((i_vwrite_start) && ({1'b0,write_ptr}==(cur_vector_length-7'b1)))
					   vec_state <= WRITE;
					else if ({1'b0,write_ptr}==(cur_vector_length-7'b1))
					   vec_state <= IDLE;
		      end
		CHAIN:begin
		         if({1'b0,read_ptr}==(cur_vector_length - 7'b1))
					   vec_state <= IDLE;
		      end
	endcase


endmodule
