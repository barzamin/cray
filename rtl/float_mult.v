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

module float_mult(clk,rst, i_cip,i_vstart,i_vector_length,i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7,i_sj, i_sk,o_busy, o_result);

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
reg [47:0] temp0;
reg [47:0] temp1;
reg [47:0] temp2;
reg [47:0] temp3;
reg [47:0] temp4;
reg [47:0] temp5;

wire [6:0] instr;
reg [6:0]  instr0, instr1, instr2, instr3, instr4, instr5;
reg [6:0]  reservation_time;
//partial products
wire [48:0] PP0, PP1, PP2, PP3, PP4, PP5;
wire [48:0] PP6, PP7, PP8, PP9, PP10, PP11, PP12, PP13, PP14, PP15;
wire [48:0] PP16, PP17, PP18, PP19, PP20, PP21, PP22, PP23, PP24, PP25, PP26, PP27, PP28, PP29, PP30, PP31;
wire [48:0] PP32, PP33, PP34, PP35, PP36, PP37, PP38, PP39, PP40, PP41, PP42, PP43, PP44, PP45, PP46, PP47;

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

localparam PRODUCT        = 7'b0110100,
           HALF_PREC_PROD = 7'b0110101,
           ROUND_PROD     = 7'b0110110,
           TWO_MINUS      = 7'b0110111;

assign expj_gt_expk = selected_j_src[61:48] > selected_k_src[61:48];

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
    m_sign0 <= selected_j_src[63]^selected_k_src[63];       //compute sign bit of mantissa - result is only negative if only one of them is negative
    case({selected_j_src[62],selected_k_src[62],expj_gt_expk})
        3'b000:begin
                exp0    <= selected_j_src[61:48] + selected_k_src[61:48];               //both negative
                e_sign0 <= 1'b0;
               end
        3'b001:begin 
                exp0    <= selected_j_src[61:48] + selected_k_src[61:48];               //both negative
                e_sign0 <= 1'b0;
               end
        3'b010:begin                                                 //sj=+, sk=-, sj <= sk
                exp0    <= selected_k_src[61:48] - selected_j_src[61:48];
                e_sign0 <= 1'b0;                                     //result=-
               end
        3'b011:begin                                                 //sj=+, sk=-, sj > sk
                exp0    <= selected_j_src[61:48] - selected_k_src[61:48];
                e_sign0 <= 1'b1;                                //result=+
               end
        3'b100:begin                                                 //sj=-, sk=+, sj <= sk
                exp0    <= selected_k_src[61:48] - selected_j_src[61:48];
                e_sign0 <= 1'b1;                                //result=+
               end
        3'b101:begin                                                 //sj=-, sk=+, sj > sk
                exp0    <= selected_j_src[61:48] - selected_k_src[61:48];
                e_sign0 <= 1'b0;                                //result=-
               end
        3'b110:begin
                exp0 <= selected_j_src[61:48] + selected_k_src[61:48];               //both positive
                e_sign0 <= 1'b1;
               end
        3'b111:begin
                exp0 <= selected_j_src[61:48] + selected_k_src[61:48];               //both positive
                e_sign0 <= 1'b1;
               end
    endcase

    //now just include all of the pipelining
    exp1 <= exp0;
    exp2 <= exp1;
    exp3 <= exp2;
    exp4 <= exp3;
    exp5 <= PP47[48] ? exp4 : (e_sign4 ? (exp4) : (exp4 + 14'b1));      //if we need to shift the final answer by 1, readjust the exponents
    m_sign1 <= m_sign0;
    m_sign2 <= m_sign1;
    m_sign3 <= m_sign2;
    m_sign4 <= m_sign3;
    m_sign5 <= m_sign4;
    e_sign1 <= e_sign0;
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


//FIXME: I don't think all of this shifting stuff is implemented correctly.
assign PP0 = ((instr==ROUND_PROD) ? 48'h800000000000 : 48'b0) + (selected_j_src[0] ? {selected_k_src[47:33],33'b0} : 48'b0);        //PP0 = 15 bits  - this should add a "1" as a "round bit" at position 2^-49
assign PP1 = PP0[48:1] + (selected_j_src[1] ? {selected_k_src[47:32],32'b0} : 48'b0);    //PP1 = 16 bits
assign PP2 = PP1[48:1] + (selected_j_src[2] ? {selected_k_src[47:31],31'b0} : 48'b0);    //PP2 = 17 bits
assign PP3 = PP2[48:1] + (selected_j_src[3] ? {selected_k_src[47:30],30'b0} : 48'b0);    //PP3 = 18 bits
assign PP4 = PP3[48:1] + (selected_j_src[4] ? {selected_k_src[47:29],29'b0} : 48'b0);  //PP4 = 19 bits
assign PP5 = PP4[48:1] + (selected_j_src[5] ? {selected_k_src[47:28],28'b0} : 48'b0);  //PP5 = 20 bits
assign PP6 = PP5[48:1] + (selected_j_src[6] ? {selected_k_src[47:32],32'b0} : 48'b0);       //16 bits
assign PP7 = PP6[48:1] + (selected_j_src[7] ? {selected_k_src[47:31],31'b0} : 48'b0);       //17 bits

assign PP8  = temp0[47:0] + (sj_cf1[8] ? {sk_cf1[47:30],30'b0} : 48'b0);        //18 bits
assign PP9  = PP8[48:1] + (sj_cf1[9]   ? {sk_cf1[47:29],29'b0} : 48'b0);        //19 bits
assign PP10 = PP9[48:1] + (sj_cf1[10]  ? {sk_cf1[47:28],28'b0} : 48'b0);        //20 bits
assign PP11 = PP10[48:1] + (sj_cf1[11] ? {sk_cf1[47:27],27'b0} : 48'b0);        //21 bits
assign PP12 = PP11[48:1] + (sj_cf1[12] ? {sk_cf1[47:23],23'b0} : 48'b0);        //25 bits
assign PP13 = PP12[48:1] + (sj_cf1[13] ? {sk_cf1[47:22],22'b0} : 48'b0);        //26 bits
assign PP14 = PP13[48:1] + (sj_cf1[14] ? {sk_cf1[47:21],21'b0} : 48'b0);        //27 bits
assign PP15 = PP14[48:1] + (sj_cf1[15] ? {sk_cf1[47:20],20'b0} : 48'b0);        //28 bits
// Still need to look up how many bits to actually use for the following adds
assign PP16 = temp1[47:0] + (sj_cf2[16] ? {sk_cf2[47:19],19'b0} : 48'b0);       //29 bits
assign PP17 = ((instr1==HALF_PREC_PROD) ? 48'h800000000000 : 48'b0) + PP16[48:1] + (sj_cf2[17] ?  {sk_cf2[47:18],18'b0} : 48'b0);         //30 bits     //add half precision round bit
assign PP18 = ((instr1==HALF_PREC_PROD) ? 48'h800000000000 : 48'b0) + PP17[48:1] + (sj_cf2[18] ?  {sk_cf2[47:22],22'b0} : 48'b0);         //26 bits     //add half precision round bit
assign PP19 = PP18[48:1] + (sj_cf2[19] ?  {sk_cf2[47:21],21'b0} : 48'b0);        //27 bits
assign PP20 = PP19[48:1] + (sj_cf2[20] ?  {sk_cf2[47:20],20'b0} : 48'b0);        //28 bits
assign PP21 = PP20[48:1] + (sj_cf2[21] ?  {sk_cf2[47:19],19'b0} : 48'b0);        //29 bits
assign PP22 = PP21[48:1] + (sj_cf2[22] ?  {sk_cf2[47:18],18'b0} : 48'b0);        //30 bits
assign PP23 = PP22[48:1] + (sj_cf2[23] ?  {sk_cf2[47:17],17'b0} : 48'b0);        //31 bits

assign PP24 = temp2[47:0] + (sj_cf3[24] ? {sk_cf3[47:13],13'b0} : 48'b0);       //35 bits
assign PP25 = PP24[48:1] + (sj_cf3[25] ? {sk_cf3[47:12],12'b0} : 48'b0);        //36 bits
assign PP26 = PP25[48:1] + (sj_cf3[26] ? {sk_cf3[47:11],11'b0} : 48'b0);        //37 bits
assign PP27 = PP26[48:1] + (sj_cf3[27] ? {sk_cf3[47:10],10'b0} : 48'b0);        //38 bits
assign PP28 = PP27[48:1] + (sj_cf3[28] ? {sk_cf3[47:9],9'b0}   : 48'b0);        //39 bits
assign PP29 = PP28[48:1] + (sj_cf3[29] ? {sk_cf3[47:8],8'b0}   : 48'b0);        //40 bits
assign PP30 = PP29[48:1] + (sj_cf3[30] ? {sk_cf3[47:9],9'b0}   : 48'b0);        //39 bits
assign PP31 = PP30[48:1] + (sj_cf3[31] ? {sk_cf3[47:9],9'b0}   : 48'b0);        //39 bits

assign PP32 = temp3[47:0] + (sj_cf4[32] ? {sk_cf4[47:8],8'b0}  : 48'b0);        //40 bits
assign PP33 = PP32[48:1] + (sj_cf4[33] ? {sk_cf4[47:8],8'b0}   : 48'b0);        //40 bits
assign PP34 = PP33[48:1] + (sj_cf4[34] ? {sk_cf4[47:7],7'b0}   : 48'b0);        //41 bits
assign PP35 = PP34[48:1] + (sj_cf4[35] ? {sk_cf4[47:6],6'b0}   : 48'b0);        //42 bits
assign PP36 = PP35[48:1] + (sj_cf4[36] ? {sk_cf4[47:3],3'b0}   : 48'b0);        //45 bits
assign PP37 = PP36[48:1] + (sj_cf4[37] ? {sk_cf4[47:2],2'b0}   : 48'b0);        //46 bits
assign PP38 = PP37[48:1] + (sj_cf4[38] ? {sk_cf4[47:1],1'b0}   : 48'b0);        //47 bits
assign PP39 = PP38[48:1] + (sj_cf4[39] ? sk_cf4[47:0] : 48'b0);                //48 bits

assign PP40 = temp4[47:0] + (sj_cf5[40] ? sk_cf5[47:0] : 48'b0);
assign PP41 = PP40[48:1] + (sj_cf5[41] ? sk_cf5[47:0]  : 48'b0);
assign PP42 = PP41[48:1] + (sj_cf5[42] ? sk_cf5[47:0]  : 48'b0);
assign PP43 = PP42[48:1] + (sj_cf5[43] ? sk_cf5[47:0]  : 48'b0);
assign PP44 = PP43[48:1] + (sj_cf5[44] ? sk_cf5[47:0]  : 48'b0);
assign PP45 = PP44[48:1] + (sj_cf5[45] ? sk_cf5[47:0]  : 48'b0);
assign PP46 = PP45[48:1] + (sj_cf5[46] ? sk_cf5[47:0]  : 48'b0);
assign PP47 = PP46[48:1] + (sj_cf5[47] ? sk_cf5[47:0]  : 48'b0);

always@(posedge clk)
begin
//store the partial products between multiply stages
   temp0[47:0] <= PP7[48:1];
   temp1[47:0] <= PP15[48:1];
   temp2[47:0] <= PP23[48:1];
   temp3[47:0] <= PP31[48:1];
   temp4[47:0] <= PP39[48:1];
//shift it over by 1 if the MSB is 0
   temp5[47:0] <= PP47[48] ? ((instr4==HALF_PREC_PROD) ? {PP47[48:19],18'b0} : PP47[48:1]) : ((instr4==HALF_PREC_PROD) ? ({PP47[48:19],18'b0} << 1) : (PP47[48:1] << 1)); 
//also pass the multiplicand and multiplier along in the pipeline
   sj_cf0 <= selected_j_src[47:0];
   sk_cf0 <= selected_k_src[47:0];
   sj_cf1 <= sj_cf0;
   sk_cf1 <= sk_cf0;
   sj_cf2 <= sj_cf1;
   sk_cf2 <= sk_cf1;
   sj_cf3 <= sj_cf2;
   sk_cf3 <= sk_cf2;
   sj_cf4 <= sj_cf3;
   sk_cf4 <= sk_cf3;
   sj_cf5 <= sj_cf4;
   sk_cf5 <= sk_cf4;
end



endmodule
