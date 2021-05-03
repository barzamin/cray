//////////////////////////////////////////////////////////////////
//        Cray Instruction Buffer                               //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the block of instruction buffers. Each of the four 
//buffers can hold 64 16-bit parcels. Instruction buffers load
//64-bit words from memory

module i_buf(clk, rst, i_p_addr, o_nip_nxt, o_word_nxt, o_nip_vld, o_mem_ce, o_mem_addr, i_mem_data, i_mem_vld);

input  wire clk;
input  wire rst;
input  wire [23:0] i_p_addr;
output reg [15:0]  o_nip_nxt;
output reg [63:0]  o_word_nxt;
output wire        o_nip_vld;
//64-bit wide memory interface
output wire        o_mem_ce;
output wire [21:0] o_mem_addr;
input  wire [63:0] i_mem_data;
input  wire        i_mem_vld;


reg [17:0] buf_delay;
reg [17:0] cur_buf;
//instruction buffers
reg [63:0] buf0 [15:0];
reg [63:0] buf1 [15:0];
reg [63:0] buf2 [15:0];
reg [63:0] buf3 [15:0];

wire [63:0] cur_buf0_word, cur_buf1_word, cur_buf2_word, cur_buf3_word;

//beginning address registers
reg [17:0] beg_addr0, beg_addr1, beg_addr2, beg_addr3;

//Buffers get replaced with an LRU policy based on the 2-bit buffer counter
reg [1:0] buf_cnt;
reg [4:0] mem_cnt;

reg [1:0] buf_state;      //state register


wire buf0_match, buf1_match, buf2_match, buf3_match;
wire no_match;
wire load_complete;

localparam IDLE = 2'b00,
           WAIT = 2'b01,
           RX   = 2'b10;
localparam BUF_FULL = 4'b1111;



//This bit is kind of weird. There is a 2-cycle delay for some reason
//when the selected buffer changes. The incoming address is the address
//being sent out on the "nip_nxt" port, though, so I'm just implementing
//this by delaying the 'buffer address' lines by  2 cycles, and then
//ANDing (i_buf_addr==cur_buf_addr) with the o_nip_vld signal to get the 
//expected behavior
always@(posedge clk)
   begin
	   buf_delay <= i_p_addr[23:6];
		cur_buf   <= buf_delay;
	end

//Enable memory if we're trying to fill a buffer, and provide the correct address
assign o_mem_ce = (buf_state == RX);
assign o_mem_addr = i_p_addr[23:2] + mem_cnt;

//tell the main block if the next instruction parcel is valid or not
assign o_nip_vld = (buf0_match || buf1_match || buf2_match || buf3_match) && (cur_buf==i_p_addr[23:6]);

//Let's check if the incoming address matches any beginning addresses
assign buf0_match = (cur_buf == beg_addr0);
assign buf1_match = (cur_buf == beg_addr1);
assign buf2_match = (cur_buf == beg_addr2);
assign buf3_match = (cur_buf == beg_addr3);

assign no_match = ~(buf0_match || buf1_match || buf2_match || buf3_match);


//increment the memory counter whenever we're in RX state and the data is valid
always@(posedge clk)
   if(rst)
      mem_cnt <= 5'b0;
   else if(buf_state==RX)
      mem_cnt <= mem_cnt + 4'b1;
	else if (mem_cnt == BUF_FULL + 1)
	   mem_cnt <= 5'b0;

//Fill in the correct buffer as we're loading from memory
always@(posedge clk)
if((buf_cnt==2'b00) && i_mem_vld)
   buf0[mem_cnt-1] <= i_mem_data;
	
always@(posedge clk)
if((buf_cnt==2'b01) && i_mem_vld)
   buf1[mem_cnt-1] <= i_mem_data;

always@(posedge clk)
if((buf_cnt==2'b10) && i_mem_vld)
   buf2[mem_cnt-1] <= i_mem_data;
	
always@(posedge clk)
if((buf_cnt==2'b11) && i_mem_vld)
   buf3[mem_cnt-1] <= i_mem_data;
	
//detect when we're done loading
assign load_complete = i_mem_vld && (mem_cnt==BUF_FULL+1);

//load the 'beginning address' registers of each buffer when we finish a load
always@(posedge clk)
   if(rst)
      beg_addr0 <= 18'b111111111111111111;
   else if((buf_cnt == 2'b00) && load_complete)
      beg_addr0 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst)
      beg_addr1 <= 18'b111111111111111111;
   else if((buf_cnt == 2'b01) && load_complete)
      beg_addr1 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst)
      beg_addr2 <= 18'b111111111111111111;
   else if((buf_cnt == 2'b10) && load_complete)
      beg_addr2 <= i_p_addr[23:6];

always@(posedge clk)
   if(rst)
      beg_addr3 <= 18'b111111111111111111;
   else if((buf_cnt == 2'b11) && load_complete)
      beg_addr3 <= i_p_addr[23:6];



//Now that the load is finished, increment the buffer counter every time we fill a buffer
always@(posedge clk)
   if(rst)
      buf_cnt <= 2'b00;
   else if (load_complete)
      buf_cnt <= buf_cnt + 2'b1;
		
		
		
//now lets select some data
assign cur_buf0_word = buf0[i_p_addr[5:2]];
assign cur_buf1_word = buf1[i_p_addr[5:2]];
assign cur_buf2_word = buf2[i_p_addr[5:2]];
assign cur_buf3_word = buf3[i_p_addr[5:2]];

//select the correct 16-bit parcel out of the current 64-bit word
always@*
begin
   case({buf0_match, buf1_match, buf2_match, buf3_match})
      4'b1000:case(i_p_addr[1:0])
                 2'b00:o_nip_nxt=cur_buf0_word[15:0];
                 2'b01:o_nip_nxt=cur_buf0_word[31:16];
                 2'b10:o_nip_nxt=cur_buf0_word[47:32];
                 2'b11:o_nip_nxt=cur_buf0_word[63:48];
              endcase

      4'b0100:case(i_p_addr[1:0])
                 2'b00:o_nip_nxt=cur_buf1_word[15:0];
                 2'b01:o_nip_nxt=cur_buf1_word[31:16];
                 2'b10:o_nip_nxt=cur_buf1_word[47:32];
                 2'b11:o_nip_nxt=cur_buf1_word[63:48];
              endcase

      4'b0010:case(i_p_addr[1:0])
                 2'b00:o_nip_nxt=cur_buf2_word[15:0];
                 2'b01:o_nip_nxt=cur_buf2_word[31:16];
                 2'b10:o_nip_nxt=cur_buf2_word[47:32];
                 2'b11:o_nip_nxt=cur_buf2_word[63:48];
              endcase

      4'b0001:case(i_p_addr[1:0])
                 2'b00:o_nip_nxt=cur_buf3_word[15:0];
                 2'b01:o_nip_nxt=cur_buf3_word[31:16];
                 2'b10:o_nip_nxt=cur_buf3_word[47:32];
                 2'b11:o_nip_nxt=cur_buf3_word[63:48];
              endcase

      default: o_nip_nxt = 16'b0;
   endcase
end

//and we need to output the whole current 64-bit word (for exchange packages)
always@*
begin
   case({buf0_match, buf1_match, buf2_match, buf3_match})
      4'b1000:o_word_nxt = cur_buf0_word;
      4'b0100:o_word_nxt = cur_buf1_word;
      4'b0010:o_word_nxt = cur_buf2_word;         
      4'b0001:o_word_nxt = cur_buf3_word;
      default:o_word_nxt = 64'b0;
   endcase
end
//State machine to retrieve 128-byte chunks from memory
always@(posedge clk)
if(rst)
   buf_state <= IDLE;
else
   case(buf_state)
      IDLE: if(no_match && !load_complete) 
		         buf_state <= RX;
        RX: if ((mem_cnt==BUF_FULL) && i_mem_vld) 
		         buf_state <= IDLE;
   endcase




endmodule
