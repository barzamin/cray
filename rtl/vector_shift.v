//******************************************
//       Vector Shift Unit
//******************************************
//
//The functional time is 4 clock periods.

module vector_shift(clk, rst,i_start, i_vl, i_j, i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7, i_ak, i_instr, i_k, o_result, o_busy);

    input wire        clk;
	 input wire        rst;
    input wire        i_start;
	 input wire [6:0]  i_vl;
    input wire [63:0] i_v0;
    input wire [63:0] i_v1;        
    input wire [63:0] i_v2;
    input wire [63:0] i_v3;
    input wire [63:0] i_v4;
    input wire [63:0] i_v5;
    input wire [63:0] i_v6;
    input wire [63:0] i_v7;
    input wire [23:0] i_ak;
    input wire [6:0]  i_instr;
    input wire [2:0]  i_k;
	 input wire [2:0]  i_j;
    output reg [63:0] o_result;
	 output wire       o_busy;

    reg [6:0]  temp_instr;
    reg [6:0]  temp_ak;
    reg [63:0] vj0, vj1;
	 reg [2:0]  cur_j;
    reg [63:0] temp_result;
    reg [63:0] comb_result;
    wire [127:0] double_vj;
    wire [127:0] rshift_d_vj;
    wire [127:0] lshift_d_vj;
    reg  [6:0]   reservation_time;
    wire         bigger_than_64; 
	 wire [63:0] v_rd_data [7:0];

localparam S_LSHIFT = 7'b1101000,       //single left shift
           S_RSHIFT = 7'b1101001,       //single right shift
           D_LSHIFT = 7'b1100010,       //double left shift
           D_RSHIFT = 7'b1100011;       //double right shift
     
assign v_rd_data[0] = i_v0;
assign v_rd_data[1] = i_v1;
assign v_rd_data[2] = i_v2;
assign v_rd_data[3] = i_v3;
assign v_rd_data[4] = i_v4;
assign v_rd_data[5] = i_v5;
assign v_rd_data[6] = i_v6;
assign v_rd_data[7] = i_v7;

//Set up the reservation system so that we report when we're busy
assign o_busy = (reservation_time != 7'b0);
always@(posedge clk)
   if(rst)
	   reservation_time <= 7'b0;
   else if(i_start)
	   reservation_time <= (i_vl > 7'b0000100) ? (i_vl + 7'b0000100) : (7'b0000101 + 7'b0000100);
	else if(reservation_time != 7'b0)
	   reservation_time <= reservation_time - 7'b1;
		
		
//grab the instruction and Ak value when we start a new vector operation
always@(posedge clk)
   if(i_start)
   begin
      temp_instr <= i_instr;                        //grab the instruction
      temp_ak    <= (i_k==3'b000) ? 7'b1 : (bigger_than_64 ? 7'b1000000 : i_ak[6:0]);   //grab Ak (k==0 is special case => Ak=1), max out at 64
      cur_j      <= i_j;
   end

//figure out if Ak wants us to shift 64 places or more
assign bigger_than_64 = i_ak >= 24'b1000000;

always@(posedge clk)
begin
   vj0         <= v_rd_data[cur_j];      //grab the new Vj input, and buffer it for 1 cycle
   vj1         <= vj0;       //Vj1 will provide the operand the for shift operation
   temp_result <= comb_result;
   o_result    <= temp_result;
end

assign double_vj  = {vj1,vj0};
assign rshift_d_vj = double_vj >> temp_ak;
assign lshift_d_vj = double_vj << temp_ak; 

always@*
begin
   case(temp_instr)
      S_LSHIFT:comb_result = vj1 << temp_ak;
      S_RSHIFT:comb_result = vj1 >> temp_ak;
      D_LSHIFT:comb_result = lshift_d_vj[127:64];
      D_RSHIFT:comb_result = rshift_d_vj[63:0];
		default: comb_result = 64'b0;
   endcase
end


endmodule
