//******************************************
//       Memory Functional Unit
//******************************************
//
//This block is essentially the memory controller
//for the Cray-1A. It handles actually reading/writing
//to on-die SRAM block. It also handles all of the pipeline
//faking used to try to get the timing right. I don't think the
//timing is actually cycle-accurate at the moment, but it should
//be 11 clock periods of delay (I believe). I also don't emulate
//the different memory 'banks'. The actual Cray-1A used 8-16 banks
//of memory, and each bank could respond every 4 cycles. I'm just 
//using 1 bank that can respond every cycle.


module mem_fu(clk,
              rst,
              i_cip,
				  i_cip_vld,
				  i_lip,
				  i_lip_vld,
				  i_vector_length,
				  i_vstart,
				  //interface to A rf
				  i_a0_data,
				  i_ai_data,
				  i_ak_data,
				  i_ah_data,
				  i_a_res_mask,
				  //interface to S rf
				  i_si_data,
				  i_s_res_mask,
				  //interface to V regs
				  i_v0_data,
				  i_v1_data,
				  i_v2_data,
				  i_v3_data,
				  i_v4_data,
				  i_v5_data,
				  i_v6_data,
				  i_v7_data,
				  //interface to B rf
				  o_b_rd_addr,
				  i_b_rd_data,
				  o_b_wr_addr,
				  o_b_wr_en,
				  //interface to T rf
				  o_t_rd_addr,
				  i_t_rd_data,
				  o_t_wr_addr,
				  o_t_wr_en,
				  //output 
				  //memory interface
				  o_mem_data,
				  o_mem_addr,
				  i_mem_rd_data,
				  o_mem_wr_data,
				  o_mem_wr_en,
				  o_mem_type,
				  o_mem_issue,
				  o_mem_busy);
				  
//system signals
input wire clk;                     //system clock
input wire rst;
input wire [15:0] i_cip;            //current instruction parcel
input wire        i_cip_vld;
input wire [15:0] i_lip;            //lower instruction parcel
input wire        i_lip_vld;
input wire [6:0]  i_vector_length; 
input wire        i_vstart;

//interface to registers
input wire [23:0] i_a0_data;
input wire [23:0] i_ai_data;
input wire [23:0] i_ak_data;
input wire [23:0] i_ah_data;
input wire [7:0]  i_a_res_mask;

input wire [63:0] i_si_data;
input wire [7:0]  i_s_res_mask;

input wire [63:0] i_v0_data;
input wire [63:0] i_v1_data;
input wire [63:0] i_v2_data;
input wire [63:0] i_v3_data;
input wire [63:0] i_v4_data;
input wire [63:0] i_v5_data;
input wire [63:0] i_v6_data;
input wire [63:0] i_v7_data;

output reg  [5:0] o_b_rd_addr;
input wire [23:0] i_b_rd_data;
output reg  [5:0] o_b_wr_addr;
output wire       o_b_wr_en;

output reg  [5:0] o_t_rd_addr;
input  wire [63:0]i_t_rd_data;
output reg  [5:0] o_t_wr_addr;
output wire       o_t_wr_en;

output reg  [63:0] o_mem_data;        //data output to registers
//interface to memory
output wire [21:0] o_mem_addr;
input  wire [63:0] i_mem_rd_data;
output reg  [63:0] o_mem_wr_data;
output wire        o_mem_wr_en;
//instruction issue
output wire       o_mem_type;
output wire       o_mem_issue;
output wire       o_mem_busy;

wire [21:0] mem_rd_addr;
wire [21:0] mem_wr_addr;
wire [21:0] jkm;
wire v_type;
wire v_vld;
wire b_t_type;
wire b_t_vld;
wire a_s_type;
wire a_s_vld;
wire mem_vld;
reg  [1:0]  state;
reg  [21:0] mem_address;     //the memory address to read/write
reg  [21:0] start_mem_addr;
reg  [21:0] stride;          //the amount to increment the address by
reg  [21:0] start_stride;
reg  [7:0]  count;           //the number of elements we should read/write
reg  [7:0]  start_count;
reg  [3:0]  source;
reg  [3:0]  start_source;
reg  [5:0]  rf_wr_addr;
reg  [5:0]  rf_rd_addr;
reg  [6:0]  remaining_write_count;
reg         reg_conflict;
reg mem_read;
reg  [3:0] write_delay;
reg  [3:0] read_delay;
wire read_complete;
wire write_complete;

reg [21:0] v_addr;
reg [21:0] b_t_addr;

reg [6:0] busy_cnt;
reg [6:0] execution_time;
reg [63:0] dat_delay0, dat_delay1, dat_delay2, dat_delay3, dat_delay4, dat_delay5, dat_delay6, dat_delay7, dat_delay8;

localparam IDLE = 2'b00,
           READ = 2'b01,
			  WRITE= 2'b10,
			  ERR  = 2'b11;
			  
localparam V0   = 4'b0000,
           V1   = 4'b0001,
			  V2   = 4'b0010,
			  V3   = 4'b0011,
			  V4   = 4'b0100,
			  V5   = 4'b0101,
			  V6   = 4'b0110,
			  V7   = 4'b0111,
           B_RF = 4'b1000,
           T_RF = 4'b1001,
			  AI   = 4'b1010,
			  SI   = 4'b1011,
			  NONE = 4'b1100;
			  
			  
           
			  
//Let's figure out what address we're supposed to read from
// - there are 3 possible sources - the b/t type (starting at A0, increment by 1)
//                                - the a/s type (read from Ah + jkm)
//                                - the v type   (start at A0, increment by Ak) 


assign o_mem_addr = mem_address;

//there's an 11-cycle access time necessary to retreive a value from memory
//We have a single-cycle SRAM, so these are just here to simulate the delay
always@(posedge clk)
   begin
	   dat_delay0 <= i_mem_rd_data;
	   dat_delay1 <= dat_delay0;
		dat_delay2 <= dat_delay1;
		dat_delay3 <= dat_delay2;
		dat_delay4 <= dat_delay3;
		dat_delay5 <= dat_delay4;
		dat_delay6 <= dat_delay5;
		dat_delay7 <= dat_delay6;
		o_mem_data <= dat_delay7;
	end

//Figure out what type, if any, of memory access it is
assign b_t_type=(i_cip[15:11]==5'b00111);    //034-037 - 1 parcel
assign b_t_vld = b_t_type && i_cip_vld;

assign a_s_type=(i_cip[15:14]==2'b10);       //100-137 - 2 parcels
assign a_s_vld = a_s_type && i_cip_vld && i_lip_vld && !reg_conflict;

assign v_type  =(i_cip[15:9]==7'o176) || (i_cip[15:9]==7'o177); //176-177 - 1 parcel
assign v_vld   = v_type && i_vstart;

assign mem_vld = b_t_vld || a_s_vld || v_vld;

//OR them all so we know it's a mem access
assign o_mem_type = b_t_type || a_s_type || v_type;

//finally calculate the write delay

assign jkm={i_cip[5:0],i_lip[15:0]};

//Let's do some decoding
always@*
   casez(i_cip[15:9])
	   7'b0011100:begin               //034 - Move (Ai) words from mem, starting at A0, to B RF, starting at JK
		              mem_read = 1;        
						  start_mem_addr = i_a0_data[21:0];
						  start_stride = 1;
						  start_count = i_ai_data;
						  start_source = NONE;
						  execution_time = (i_ai_data==0) ? 5 : (9 + i_ai_data);
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
					   end 
		7'b0011101:begin               //035 - Move (Ai) words from B RF, starting at JK, to mem starting at A0
		              mem_read=0;  
                    start_mem_addr = i_a0_data[21:0];
                    start_stride = 1;
                    start_count = i_ai_data;
						  start_source = B_RF;
						  execution_time = (i_ai_data==0) ? 7 : (6 + i_ai_data);
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
                 end						  
		7'b0011110:begin               //036 - Move (Ai) words from mem, starting at A0, to T RF, starting at JK
		              mem_read = 1;        
						  start_mem_addr = i_a0_data[21:0];
						  start_stride = 1;
						  start_count = i_ai_data;
						  start_source = NONE;
						  execution_time = (i_ai_data==0) ? 5 : (9 + i_ai_data);
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
					   end 
		7'b0011111:begin               //037 - Move (Ai) words from T RF, starting at JK, to mem starting at A0
		              mem_read=0;  
                    start_mem_addr = i_a0_data[21:0];
                    start_stride = 1;
                    start_count = i_ai_data;
						  start_source = T_RF;
						  execution_time = (i_ai_data==0) ? 7 : (6 + i_ai_data);
						  reg_conflict = i_a_res_mask[0] || i_a_res_mask[i_cip[8:6]];  //check for a conflict with Ai or A0
                 end						
		7'b1000???:begin
		              mem_read=1;        //10hijkm - Read from (Ah + jkm) to Ai
                    start_mem_addr = i_ah_data[21:0] + jkm;
						  start_stride = 0;
						  start_count = 1;
						  start_source = NONE;
						  execution_time = 3;
						  reg_conflict = i_a_res_mask[i_cip[8:6]] || i_a_res_mask[i_cip[11:9]];
                 end
		7'b1001???:begin
		              mem_read=0;        //11hijkm - Store (Ai) to (Ah + jkm)
                    start_mem_addr = i_ah_data[21:0] + jkm;
						  start_stride = 1;
						  start_count = 1;
						  start_source = AI;
						  execution_time = 1;
						  reg_conflict = i_a_res_mask[i_cip[8:6]] || i_a_res_mask[i_cip[11:9]];
                 end
		7'b1010???:begin
		              mem_read=1;        //12hijkm - Read from (Ah + jkm) to Si
                    start_mem_addr = i_ah_data[21:0] + jkm;
						  start_stride = 0;
						  start_count = 1;
						  start_source = NONE;
						  execution_time = 3;
						  reg_conflict = i_a_res_mask[i_cip[11:9]] || i_s_res_mask[i_cip[8:6]];
                 end
		7'b1011???:begin
		              mem_read=0;        //13hijkm - Store (Si) to (Ah + jkm)
                    start_mem_addr = i_ah_data[21:0] + jkm;
						  start_stride = 0;
						  start_count = 1;
						  start_source = SI;
						  execution_time = 1;
						  reg_conflict =  i_a_res_mask[i_cip[11:9]] || i_s_res_mask[i_cip[8:6]];
                 end
		7'b1111110:begin
		              mem_read = 1;        //176 - Read VL elements from memory to Vi, starting at A0, stride Ak
						  start_mem_addr = i_a0_data[21:0];
						  start_stride = i_ak_data[21:0];
						  start_count  = i_vector_length;
						  start_source = NONE;
						  execution_time = (i_vector_length <= 5) ? 14 : (i_vector_length + 9);
						  reg_conflict = 0;
					  end
		7'b1111111:begin
		              mem_read=0;        //177 - Write VL elements into memory from Vj, starting at A0, stride Ak
						  start_mem_addr = i_a0_data[21:0];
						  start_stride = i_ak_data[21:0];
						  start_count = i_vector_length;
						  start_source = {1'b0,i_cip[5:3]};  //encode the Vj register as the source
						  execution_time = (i_vector_length <= 5) ? 5 : i_vector_length + 5;
						  reg_conflict = 0;
					  end
		default:begin
		           mem_read=0;
					  execution_time = 0;
					  reg_conflict = 0;
					  start_mem_addr = 0;
					  start_stride = 0;
					  start_count = 0;
					  start_source = NONE;
				  end
	endcase



always@(posedge clk)
   if(rst)
	   state <= IDLE;
	else 
	case(state)
	   IDLE: if(mem_vld && mem_read)
	            state <= READ;
	         else if(mem_vld && !mem_read)
	            state <= WRITE;
      READ: if(read_complete) 
		         state <= IDLE;
      WRITE:if(write_complete)
		         state <= IDLE;
      default: state <= IDLE;
    endcase		

assign write_complete = (state==WRITE) && (busy_cnt==7'b0); //(write_delay==3'b0) && (remaining_write_count==0);
assign read_complete  = (state==READ)  && (busy_cnt==7'b0);

always@(posedge clk)
   if((state==IDLE) && mem_vld)
	   rf_rd_addr <= i_cip[5:0];       //load jk as the starting address for the register files
	else if (state==READ)
      rf_rd_addr <= rf_rd_addr + 5'b00001;	 //otherwise keep incrementing (FIXME: this needs to be qualified)

always@(posedge clk)
   if((state==IDLE) && mem_vld)
	   rf_wr_addr <= i_cip[5:0];               //load jk as the starting address for the register files
	else if((state==WRITE) && write_delay==3'b0)
      rf_wr_addr <= rf_rd_addr + 5'b00001;	 //increment after the appropriate delay

//Let's wait the appropriate amount of time if it's a write from a vector register
always@(posedge clk)
   if(rst)
	   write_delay <= 4'b0;
   else if((state==IDLE) && mem_vld && (i_cip[15:9]==7'o177))  //detect vector write to memory
	   write_delay <= 4'b0101;     //delay for 5 clock cycles so we can get the data out of the vector register
	else if((state==IDLE) && mem_vld && ((i_cip[15:9]==7'o035) || (i_cip[15:9]==7'O037)))  //or it's a write from a B reg
	   write_delay <= 4'b0110;
	else if(write_delay != 4'b0)
	   write_delay <= write_delay - 1;

//figure out how many elements we still need to write
always@(posedge clk)
   if(rst)
	   remaining_write_count = 7'b0;
	else if((state==IDLE) && o_mem_type && mem_vld)
	   remaining_write_count = start_count;
	else if((state==WRITE) && (write_delay==3'b0))
	   remaining_write_count = remaining_write_count - 7'b1;


//and choose the source to write from
always@*
   begin
	   case(start_source)
		     V0:  o_mem_wr_data = i_v0_data;   
           V1:  o_mem_wr_data = i_v1_data;
			  V2:  o_mem_wr_data = i_v2_data;   
			  V3:  o_mem_wr_data = i_v3_data;   
			  V4:  o_mem_wr_data = i_v4_data;   
			  V5:  o_mem_wr_data = i_v5_data;   
			  V6:  o_mem_wr_data = i_v6_data;   
			  V7:  o_mem_wr_data = i_v7_data;   
           B_RF:o_mem_wr_data = {40'b0,i_b_rd_data};   
           T_RF:o_mem_wr_data = i_t_rd_data;   
			  AI:  o_mem_wr_data = {40'b0,i_ai_data};   
			  SI:  o_mem_wr_data = i_si_data; 
			  default: o_mem_wr_data = 64'b0;
		endcase
   end

//calculate the memory address we use
always@(posedge clk)
   if(rst)
	   mem_address <= 22'b0;
	else if((state==IDLE) && o_mem_type)
	   mem_address <= start_mem_addr;
	else if((state==READ)||((state==WRITE) && (write_delay==3'b0)))
	   mem_address <= mem_address + stride;

//calculate the index into the B/T rf that we use
always@(posedge clk)
   if(rst)
	   begin
	      o_b_rd_addr <= 0;
		   o_t_rd_addr <= 0;
		end
	else if((state==IDLE) && o_mem_type && mem_vld)
      begin
	      o_b_rd_addr <= i_cip[5:0];
         o_t_rd_addr <= i_cip[5:0];
      end
	else if((write_delay==0) && (state==WRITE))
	   begin
	      o_b_rd_addr <= o_b_rd_addr + 1;
		   o_t_rd_addr <= o_t_rd_addr + 1;
		end
		
always@(posedge clk)
   if(rst)
	   begin
	      o_b_wr_addr <= 0;
         o_t_wr_addr <= 0;
		end
	else if((state==IDLE) && o_mem_type && mem_vld)
      begin
	      o_b_wr_addr <= i_cip[5:0];
         o_t_wr_addr <= i_cip[5:0];
		end
	else if((read_delay==0) && (state==READ))
      begin
	      o_b_wr_addr <= o_b_wr_addr + 1;
		   o_t_wr_addr <= o_t_wr_addr + 1;
		end

		
always@(posedge clk)
   if(rst)
	   busy_cnt <= 7'b0;
	else if((state==IDLE) && o_mem_type && mem_vld)
	   busy_cnt <= execution_time;
	else if (busy_cnt != 7'b0)
	   busy_cnt <= busy_cnt - 1;
		
		
always@(posedge clk)
   if(rst)
	   stride <= 0;
	else if((state==IDLE) && o_mem_type && mem_vld)
	   stride <= start_stride;
		
//Let's perform a memory write!
assign o_mem_wr_en = ((state==WRITE) && (write_delay==3'b0) && (remaining_write_count!=0));

//For a read, we need to wait 10 clock cycles for the data to be valid
always@(posedge clk)
   if(rst)
	   read_delay <= 4'b0;
	else if((state==IDLE) && o_mem_type && mem_read)
	   read_delay <= 4'b1010;  //set it to 10 cycles
	else if(read_delay != 4'b0)
	   read_delay <= read_delay - 4'b1;
		
		
//or write to some registers
assign o_b_wr_en = (i_cip[15:9]==7'o034) && (state==READ) && (read_delay==4'b0);

assign o_t_wr_en = (i_cip[15:9]==7'o036) && (state==READ) && (read_delay==4'b0);       

//finally, 'issue' the instruction when we're done 
assign o_mem_issue = !(mem_vld)||((state!=IDLE) && (busy_cnt==7'b0) && b_t_type) ||
                     ((state!=IDLE) && (busy_cnt==7'b0) && ((i_cip[15:12]==4'b1001) || (i_cip[15:12]==4'b1011)) && !reg_conflict);

assign o_mem_busy = (busy_cnt!=7'b0) || (state!=IDLE);
endmodule
