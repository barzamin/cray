//******************************************
//       Floating Point Multiply Unit
//******************************************
//
//It takes 7 time units to produce a 64-bit result. 
//
//      064ijk  floating product of (sj) and (sk) to Si
//      065ijk  half-precision rounded floating product of (sj) and (sk) to si
//      066ijk  rounded floating product of (sj) and (sk) to Si
//      067ijk  reciprocal iteration; 2-(Sj)*(Sk) to Si
//
// These instructions are executed by the floating point multiply unit.
// Operands are assumed to be in floating point format. The result is
// not guaranteed to be normalized if the operands are unnormalized.
//
// The 064 instruction forms the product of the floating point quantities
// in Sj and Sk and enters the result into Si.
//
// The 065 instruction forms the half-precision rounded product of the 
// floating point quantities in Sj and Sk and enters the result into Si.
// The low order 18 bits of the result are cleared.
//
// The 066 instruction forms the rounded product of the floating point
// quantities in sj and Sk and enters the result into Si.
//
// The 067 instruction forms two minus the product of the floating point
// quantities in Sj and Sk and enters the result into Si. This instruction
// is used in the divide sequence as described in section 3 under "Floating
// Point Arithmetic"

//floating point format is: {mantissa_sign[1],exponent_sign[1],exponent[14],mantissa[48]}
// Mantissa sign: 1=negative
// exponent sign: 1=positive

(*mult_style="pipe_lut"*)
module fast_float_mult(clk,rst, i_cip,i_vstart,i_vector_length,i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7,i_sj, i_sk,o_busy, o_result);

input wire clk;
input wire rst;
input wire i_vstart;
input wire [15:0] i_cip;
input wire [6:0]  i_vector_length;
input wire [63:0] i_v0;
input wire [63:0] i_v1;
input wire [63:0] i_v2;
input wire [63:0] i_v3;
input wire [63:0] i_v4;
input wire [63:0] i_v5;
input wire [63:0] i_v6;
input wire [63:0] i_v7;
input wire [63:0] i_sj;
input wire [63:0] i_sk;

output reg [63:0] o_result;
output wire o_busy;

reg [47:0] sj_cf0;
reg [47:0] sk_cf0;
reg [47:0] sj_cf1;
reg [47:0] sk_cf1;
reg [47:0] sj_cf2;
reg [47:0] sk_cf2;
reg [47:0] sj_cf3;
reg [47:0] sk_cf3;
reg [47:0] sj_cf4;
reg [47:0] sk_cf4;
reg [47:0] sj_cf5;
reg [47:0] sk_cf5;
//It takes 7 clock cycles to multiply, so we have 6 pipeline stages
// - that means we need to perform 48/6 = 8 additions per clock
reg [95:0] mult_res;
reg [95:0] pipe_2;
reg [95:0] pipe_3;
reg [95:0] MULT;
reg [47:0] temp5;

wire [6:0] instr;
reg [6:0]  instr0, instr1, instr2, instr3, instr4, instr5;
reg [6:0]  reservation_time;
//partial products
reg [47:0] final_mantissa;


wire [47:0] two_minus_man0;
wire [47:0] two_minus_man1;
wire [13:0] two_minus_exp;
wire [47:0] final_man;
wire [13:0] final_exp;

reg [13:0] exp0, exp1, exp2, exp3, exp4, exp5;
reg m_sign0, m_sign1, m_sign2, m_sign3, m_sign4, m_sign5;
reg e_sign0, e_sign1, e_sign2, e_sign3, e_sign4, e_sign5;
wire expj_gt_expk;

wire [2:0] cip_j, cip_k;
reg  [2:0] cur_j, cur_k;
reg [63:0] v_j_src;
reg [63:0] v_k_src;
wire [63:0] selected_j_src;
wire [63:0] selected_k_src;
reg [63:0] selected_j_src_r;
reg [63:0] selected_k_src_r;

localparam PRODUCT        = 7'b0110100,
           HALF_PREC_PROD = 7'b0110101,
           ROUND_PROD     = 7'b0110110,
           TWO_MINUS      = 7'b0110111;

assign expj_gt_expk = selected_j_src_r[61:48] > selected_k_src_r[61:48];

//pull out the instruction field of the current instruction parcel
assign instr = i_cip[15:9];
assign cip_j = i_cip[5:3];
assign cip_k = i_cip[2:0];

//select the correct vector sources
always@*
   begin
	   case(cur_j)
		   3'o0:v_j_src = i_v0;
			3'o1:v_j_src = i_v1;
			3'o2:v_j_src = i_v2;
			3'o3:v_j_src = i_v3;
			3'o4:v_j_src = i_v4;
			3'o5:v_j_src = i_v5;
			3'o6:v_j_src = i_v6;
			3'o7:v_j_src = i_v7;
		endcase
	end
	
always@*
   begin
	   case(cur_k)
		   3'o0:v_k_src = i_v0;
			3'o1:v_k_src = i_v1;
			3'o2:v_k_src = i_v2;
			3'o3:v_k_src = i_v3;
			3'o4:v_k_src = i_v4;
			3'o5:v_k_src = i_v5;
			3'o6:v_k_src = i_v6;
			3'o7:v_k_src = i_v7;
		endcase
	end

//now switch between the vector and scalar sources
assign selected_j_src = (reservation_time==7'b0) ? i_sj : v_j_src;
assign selected_k_src = (reservation_time==7'b0) ? i_sk : v_k_src;

always@(posedge clk)
begin
   selected_j_src_r <= selected_j_src;
	selected_k_src_r <= selected_k_src;
end

//and now manage the FU reservation for a vector instruction
always@(posedge clk)
   if(rst)
	    reservation_time <= 7'b0;
	else if(i_vstart)
	    reservation_time <= i_vector_length + 7'b0000100;   //functional unit reservation for VL + 4
	else if(reservation_time!=7'b0)
	    reservation_time <= reservation_time - 7'b1;

always@(posedge clk)
   if(i_vstart)
	   begin
		   cur_j <= cip_j;
			cur_k <= cip_k;
		end
assign o_busy = (reservation_time != 7'b0);




always@(posedge clk)
begin
    m_sign1 <= selected_j_src_r[63]^selected_k_src_r[63];       //compute sign bit of mantissa - result is only negative if only one of them is negative
    case({selected_j_src_r[62],selected_k_src_r[62],expj_gt_expk})
        3'b000:begin
                exp1    <= selected_j_src_r[61:48] + selected_k_src_r[61:48];               //both negative
                e_sign1 <= 1'b0;
               end
        3'b001:begin 
                exp1    <= selected_j_src_r[61:48] + selected_k_src_r[61:48];               //both negative
                e_sign1 <= 1'b0;
               end
        3'b010:begin                                                 //sj=+, sk=-, sj <= sk
                exp1    <= selected_k_src_r[61:48] - selected_j_src_r[61:48];
                e_sign1 <= 1'b0;                                     //result=-
               end
        3'b011:begin                                                 //sj=+, sk=-, sj > sk
                exp1    <= selected_j_src_r[61:48] - selected_k_src_r[61:48];
                e_sign1 <= 1'b1;                                //result=+
               end
        3'b100:begin                                                 //sj=-, sk=+, sj <= sk
                exp1    <= selected_k_src_r[61:48] - selected_j_src_r[61:48];
                e_sign1 <= 1'b1;                                //result=+
               end
        3'b101:begin                                                 //sj=-, sk=+, sj > sk
                exp1    <= selected_j_src_r[61:48] - selected_k_src_r[61:48];
                e_sign1 <= 1'b0;                                //result=-
               end
        3'b110:begin
                exp1 <= selected_j_src_r[61:48] + selected_k_src_r[61:48];               //both positive
                e_sign1 <= 1'b1;
               end
        3'b111:begin
                exp1 <= selected_j_src_r[61:48] + selected_k_src_r[61:48];               //both positive
                e_sign1 <= 1'b1;
               end
    endcase

    //now just include all of the pipelining

    exp2 <= exp1;
    exp3 <= exp2;
    exp4 <= exp3;
    exp5 <= MULT[95] ? exp4 : (e_sign4 ? (exp4) : (exp4 + 14'b1));      //if we need to shift the final answer by 1, readjust the exponents

    m_sign2 <= m_sign1;
    m_sign3 <= m_sign2;
    m_sign4 <= m_sign3;
    m_sign5 <= m_sign4;

    e_sign2 <= e_sign1;
    e_sign3 <= e_sign2;
    e_sign4 <= e_sign3;
    e_sign5 <= e_sign4;         //might need to adjust this, in case the sign changes when we make the final readjustment to the exponenet

    instr0 <= instr;
    instr1 <= instr0;
    instr2 <= instr1;
    instr3 <= instr2;
    instr4 <= instr3;
    instr5 <= instr4;
end

always@(posedge clk)
   o_result[63:0] <= {m_sign5, e_sign5, final_exp[13:0], final_man[47:0]};            //this is the resulting mantissa - should be normalized now

assign two_minus_man0[47:0] = 48'h800000000000 - (exp5[0] ? (temp5[47:0] >> 1) : (temp5[47:0] >> 2));    //perform 2 - S1*S2
assign two_minus_exp[13:0] = {exp5[13:1],~exp5[0]};                                                     //adjust the exponent accordingly
assign two_minus_man1[47:0] = exp5[0] ? (two_minus_man0 << 2) : (two_minus_man0 << 1);                  //now re-normalize the result
assign final_man[47:0] = (instr==TWO_MINUS) ? two_minus_man1[47:0] : temp5[47:0];                     //now choose the right result
assign final_exp[13:0] = (instr==TWO_MINUS) ? two_minus_exp[13:0] : exp5[13:0];       



//Let's figure out how to modify the mantissa
always@*
  begin
     case(instr1)
	     PRODUCT:        final_mantissa = MULT[95:48];
        HALF_PREC_PROD: final_mantissa = {MULT[95:67],19'b0};
        ROUND_PROD:     final_mantissa = {MULT[95:49],|MULT[48:0]};    //FIXME: Not sure what to do about the rounding
        TWO_MINUS:      final_mantissa = MULT[95:48];
		  default:        final_mantissa = MULT[95:48];
	  endcase
  end



always@(posedge clk)
   begin
		//Store the operand we're working with first
	   sj_cf0 <= selected_j_src[47:0];
      sk_cf0 <= selected_k_src[47:0];
      //Multiply the two mantissas together (this should invoke fast hardware multipliers)
      mult_res <= sj_cf0 * sk_cf0;
		//Now modify it based on instruction
		pipe_2 <= mult_res;
		pipe_3 <= pipe_2;
		MULT   <= pipe_3;
      temp5 <= final_mantissa; 
   end

endmodule
