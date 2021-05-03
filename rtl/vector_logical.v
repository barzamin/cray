//******************************************
//       Vector Logical Unit
//******************************************
//
//The functional time is 2 clock periods.
//executes instructions 042-051 (mask and boolean)


module vector_logical(clk,rst, i_instr, i_start, i_sj, i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7, i_vm,i_vl, i_i, i_j, i_k, o_result, o_busy);
    input wire       i_start;
	 input wire clk;
	 input wire       rst;
    input wire [6:0] i_instr;
    input wire [2:0] i_j;
    input wire [2:0] i_k;
    input wire [2:0] i_i;
    input wire [63:0] i_sj;
    input wire [63:0] i_v0;
    input wire [63:0] i_v1;
    input wire [63:0] i_v2;
    input wire [63:0] i_v3;
    input wire [63:0] i_v4;
    input wire [63:0] i_v5;
    input wire [63:0] i_v6;
    input wire [63:0] i_v7;	 
    input wire [63:0] i_vm;        //vector mask input (i think?)
	 input wire [6:0]  i_vl;        //vector length input
    output reg [63:0] o_result;
    output wire       o_busy;
	 
    reg  [63:0] temp_sj;
    reg  [6:0]  temp_instr;
    reg  [63:0] temp_vj;
    reg  [63:0] temp_vk;
    reg  [63:0] temp_result;
    reg  [63:0] temp_scal_mrg;
    reg  [63:0] temp_vec_mrg;
    reg  [63:0] temp_vec_mask;
    reg  [2:0]  temp_k;
	 reg  [6:0]  reservation_time;
    wire        detect_clear;
    integer i;
    reg  [5:0]  vec_count;         //vector count for the vector mask generate instruction
    reg         mask_val;
    reg  [2:0]  cur_j, cur_k;
localparam SCAL_AND = 7'b1100000,
          VEC_AND  = 7'b1100001,
          SCAL_OR  = 7'b1100010,
          VEC_OR   = 7'b1100011,
          SCAL_XOR = 7'b1100100,
          VEC_XOR  = 7'b1100101,
          SCAL_MRG = 7'b1100110,
          VEC_MRG  = 7'b1100111,
          VEC_MASK = 7'b1111101;

wire [63:0] v_rd_data [7:0];

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
		
		
//detect the clear condition
assign detect_clear = (i_i==i_j) & (i_i==i_k) & (i_instr==VEC_XOR);

always@(posedge clk)
begin
//pipeline registers

temp_vj  <= detect_clear ? 64'b0 :  v_rd_data[cur_j];        //if we detect a 'clear' operation, set both vector inputs to zero so the output is zero
temp_vk  <= detect_clear ? 64'b0 :  v_rd_data[cur_k];

if(i_start)
   begin
      temp_k     <= i_k;
		cur_k      <= i_k;
		cur_j      <= i_j;
      temp_instr <= i_instr;
      temp_sj    <= (i_j==3'b000) ? 64'b0 : i_sj;  
      vec_count  <= i_vl;          //reset the vector count when we start a new instruction 
      o_result   <= 64'b0;          //i'm pretty sure we can clear this when we start a new instruction
   end
else begin
      o_result <= temp_result;
     end

end

always@*
begin
   for(i=0;i<64;i=i+1)
   begin
      temp_scal_mrg[i] = i_vm[i] ? temp_sj[i] : temp_vk[i];
      temp_vec_mrg[i]  = i_vm[i] ? temp_vj[i] : temp_vk[i];
      if(vec_count==i[5:0])
         temp_vec_mask[63-i]=mask_val;
      else
         temp_vec_mask[63-i]=1'b0;
   end
end

//now do the logic operation
always@*
begin
   case(temp_instr)
      SCAL_AND:temp_result = temp_sj & temp_vk;
      VEC_AND: temp_result = temp_vj & temp_vk;
      SCAL_OR: temp_result = temp_sj | temp_vk;
      VEC_OR:  temp_result = temp_vj | temp_vk;
      SCAL_XOR:temp_result = temp_sj ^ temp_vk;
      VEC_XOR: temp_result = temp_vj ^ temp_vk;
      SCAL_MRG:temp_result = temp_scal_mrg;
      VEC_MRG: temp_result = temp_vec_mrg;
      default: temp_result = o_result | temp_vec_mask;         //OR in the new vector mask signal to generate the new mask in a bitwise fashion
   endcase
end

//generate the vector mask
always@*
begin
   case(temp_k[1:0])
      2'b00: mask_val = (temp_vj==64'b0);
      2'b01: mask_val = (temp_vj!=64'b0);
      2'b10: mask_val = ~temp_vj[63];
      2'b11: mask_val =  temp_vj[63];
   endcase
end
endmodule
