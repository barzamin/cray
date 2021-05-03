//******************************************
//       Vector ADD UNIT
//******************************************
//
//The functional time is 3 clock periods.

module vector_add(clk,i_start,rst,i_vl,i_sj,i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7,i_instr, i_j, i_k,o_result,o_busy);

input wire clk;
input wire        i_start;      //start an operation (sample i_sj)   - needs to pulse for 1 cycle when operation starts
input wire        rst;
input wire [6:0]  i_vl;
input wire [63:0] i_sj;      
input wire [63:0] i_v0;
input wire [63:0] i_v1;        
input wire [63:0] i_v2;
input wire [63:0] i_v3;
input wire [63:0] i_v4;
input wire [63:0] i_v5;
input wire [63:0] i_v6;
input wire [63:0] i_v7;
output reg [63:0] o_result;
output wire o_busy;
input wire [6:0] i_instr;
input wire [2:0] i_j;
input wire [2:0] i_k;

reg [6:0] instr;
reg [63:0] vk_0;   //operand 1 
reg [63:0] vj_0;   //operand 2
reg [63:0] sj_0;

reg [63:0] temp_result;
reg [63:0] comb_result;
reg [2:0] cur_j, cur_k;
wire [63:0] v_rd_data [7:0];
reg [6:0] reservation_time;

localparam SCAL_VEC_ADD = 7'b1101100,
           VEC_VEC_ADD  = 7'b1101101,
           SCAL_VEC_SUB = 7'b1101110,
           VEC_VEC_SUB  = 7'b1101111;

//Set up the reservation system so that we report when we're busy
assign o_busy = (reservation_time != 7'b0);
always@(posedge clk)
   if(rst)
	   reservation_time <= 7'b0;
   else if(i_start)
	   reservation_time <= (i_vl > 7'b0000100) ? (i_vl + 7'b0000100) : (7'b0000101 + 7'b0000100);
	else if(reservation_time != 7'b0)
	   reservation_time <= reservation_time - 7'b1;
		
assign v_rd_data[0] = i_v0;
assign v_rd_data[1] = i_v1;
assign v_rd_data[2] = i_v2;
assign v_rd_data[3] = i_v3;
assign v_rd_data[4] = i_v4;
assign v_rd_data[5] = i_v5;
assign v_rd_data[6] = i_v6;
assign v_rd_data[7] = i_v7;
always@(posedge clk)
   begin
      //grab new values
      vk_0[63:0] <= v_rd_data[cur_k];
      vj_0[63:0] <= v_rd_data[cur_j];
   if(i_start)           //a new operation is starting, sample the scalar input and instruction register
      begin
         instr[6:0] <= i_instr[6:0];
         sj_0       <= i_sj;
			cur_j      <= i_j;
			cur_k      <= i_k;
      end
   end

   
always@*
begin
   case(instr)
      SCAL_VEC_ADD: comb_result = sj_0 + vk_0;
      VEC_VEC_ADD : comb_result = vj_0 + vk_0;
      SCAL_VEC_SUB: comb_result = sj_0 - vk_0;
      default:      comb_result = vj_0 - vk_0;
   endcase
end
always@(posedge clk) begin 
   temp_result[63:0] <= comb_result;           //compute result
   o_result[63:0]    <= temp_result[63:0];     //just delay for an extra cycle
end

endmodule
