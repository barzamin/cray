//*********************************************************
//       Floating Point Reciprocal Approximation Unit
//*********************************************************


//070ijx        Floating Reciprocal approximation of (Sj) to Si

//This instruction is executed in the reciprocal approximation unit.

//The instruction forms an approximation to the reciprocal of the normalized
//floatoing point quantity in Sj and enters the result into Si. This
//instruction occurs in the divide sequence to compute the quotient of
//two floating point quantities as described in section 3 under floating
//point arithmetic.

//The reciprocal approximation instruction produces a result that is
//accurate to 27 bits. A second approximation may be generated to 
//extend the accuracy to 47 bits using the reciprocal iteration instruction

//Hold issue conditions
//-> 034-037 in process
//-> exchange in process
//-> Si or Sj reserved
//-> 174 in process; unit busy (VL) + 4 CPs

//Execution time: Si ready in 14 CPs, instruction issue in 1 CP

//assumes that bit 47 of Sj is a 1 (i.e. it is already normalized)

//special cases
//-An arithmetic error allows 17 CPs + 2 parcels to issue if the fp error flag is set
//-(Si) is meaningless if (Sj)  is not normalized; the unit assumes
// that bit 47 of (Sj)=1; no test is made of this bit.
//-(Sj) = 0 produces a range error; the result is meaningless
//-(Sj) = 0 if j = 0


/*random quote from some guy:
Good ole' Cray-1 used an iterative process for floating point division 
which worked like this: given a floating point number x, use the first 8 
bits of the mantissa to index into a lookup table containing initial 
guesses, then do a few steps of Newton-Raphson iteration involving only 
multiply-add operations to get the fully converged reciprocal mantissa, 
fix the exponent, thus obtaining 1/x, then multiply y*(1/x) to get y/x.
*/

/* more accurate info:
The cray uses a 128-entry, lookup table, indexed by the first 7 bits
after the MSB of the mantissa (which is always 1). I believe the
output is 8 bits wide. This is X0, the initial guess. It then 
calculates X1, X2 and X3, the first three newton-raphson iterations.
X1 is accurate to 8 bits, X2 is accurate to 16 bits, and X3 ~ 30 bits (not sure why).
*** Correction - If the input is only 7 bits, I think the output is only like 4 bits, but that's fine


compute: X(i+1)=X(i)*(2 - D*X(i)), where D is the original mantissa
"2-X" is the two's complement of X -> Invert X and then add 1 (slightly less accurate
but quicker to just invert X, and avoid the add operation altogether).

remaining question: If an answer is only accurate to 16 bits, do I only have to perform
16 partial products?
 -> Answer: According to edmond, yes! */

// You can calculate 2*X(i) and X(i)^2


module float_recip(clk,rst,i_sj,i_vstart,i_vector_length,i_v0,i_v1,i_v2,i_v3,i_v4,i_v5,i_v6,i_v7,o_result, o_busy);

input  wire clk;        //system clock
input  wire rst;
input  wire i_vstart;
input  wire [6:0] i_vector_length;
input wire [63:0] i_v0;
input wire [63:0] i_v1;
input wire [63:0] i_v2;
input wire [63:0] i_v3;
input wire [63:0] i_v4;
input wire [63:0] i_v5;
input wire [63:0] i_v6;
input wire [63:0] i_v7;
input  wire [63:0] i_sj;
output reg [63:0] o_result;
output wire       o_busy;



reg  [2:0]  cur_j;
reg  [7:0]  reservation_time;
reg  [15:0]  sj [8:0];  
wire [63:0]  selected_src;
reg  [63:0]  tmp_src;
reg  [63:0]  v_src;

wire [3:0]  x_init;
reg  [4:0]  x0, x0_2, x0_3, x0_4;
reg  [9:0]  x1_a;
reg  [10:0] x1_b1;
reg  [10:0] x1_b2;
wire [15:0] x1_c;
reg  [7:0]  x1, x1_2, x1_3, x1_4;

reg  [15:0] x2_a;
reg  [16:0] x2_b1;
reg  [16:0] x2_b2;
wire [24:0] x2_c;
reg  [15:0] x2, x2_2, x2_3, x2_4;

reg  [31:0] x3_a;
reg  [32:0] x3_b1;
reg  [32:0] x3_b2;
wire [48:0] x3_c;
reg  [47:0] x3;
reg  [47:0] x3_2;
reg [14:0] exponent_1;
reg [14:0] exponent_2;
reg [14:0] exponent_3;
reg [14:0] exponent_4;
reg [14:0] exponent_5;
reg [14:0] exponent_6;
reg [14:0] exponent_7;
reg [14:0] exponent_8;
reg [14:0] exponent_9;
reg [14:0] exponent_10;
reg [14:0] exponent_11;
reg [14:0] exponent_12;

reg [12:0] sign;
reg [12:0] is_half;

//select the correct vector source
always@*
   begin
	   case(cur_j)
		   3'o0:v_src = i_v0;
			3'o1:v_src = i_v1;
			3'o2:v_src = i_v2;
			3'o3:v_src = i_v3;
			3'o4:v_src = i_v4;
			3'o5:v_src = i_v5;
			3'o6:v_src = i_v6;
			3'o7:v_src = i_v7;
		endcase
	end

//now switch between the vector and scalar sources
assign selected_src = (reservation_time==7'b0) ? i_sj : v_src;

//and now manage the FU reservation for a vector instruction
always@(posedge clk)
   if(rst)
	    reservation_time <= 7'b0;
	else if(i_vstart)
	    reservation_time <= i_vector_length + 7'b0000100;   //functional unit reservation for VL + 4
	else if(reservation_time!=7'b0)
	    reservation_time <= reservation_time - 7'b1;

assign o_busy = (reservation_time != 7'b0);

always@(posedge clk)
   o_result <= is_half[12] ? {sign[12],exponent_12,1'b1,47'b0} : {sign[12],exponent_12,x3};

//Pipeline the i_sj signal along
always@(posedge clk)
begin
   sj[0] <= selected_src[47:32];
	sj[1] <= sj[0];
	sj[2] <= sj[1];
	sj[3] <= sj[2];
	sj[4] <= sj[3];
	sj[5] <= sj[4];
	sj[6] <= sj[5];
	sj[7] <= sj[6];
	sj[8] <= sj[7];
end

//Detect if the input mantissa is 1/2
always@(posedge clk)
begin
   is_half[0] <= (selected_src[47:40]==8'b10000000);
   is_half[12:1] <= is_half[11:0];
end

////////////////////////////////
//      First Iteration       //
////////////////////////////////

//Clock 1
//look-up table to give us initial guess
//Input  = first 7 bits after MSB of starting mantissa
//Output = first 4 bits after MSB of result mantissa
recip_lut lut(.n(selected_src[46:40]), .mantissa(x_init));
always@(posedge clk)
begin
   x0   <= {1'b1,x_init};
   x0_2 <= x0;               //pipelinin'
	x0_3 <= x0_2;
	x0_4 <= x0_3;
end
//Clock 2
//X0 * B should be close to 1 (but slightly more than)
always@(posedge clk)
   x1_a <= x0 * sj[0][15:11];

//Clock 3
//2 - X0*B (should be slightly less than 1)
always@(posedge clk)
   x1_b1 <= (11'b10000000000 - {1'b0,x1_a});
	
//Clock 4
//now shift it as necessary
always@(posedge clk)
   x1_b2 <= x1_b1[10] ? x1_b1 : x1_b1[9] ? x1_b1 << 1 :  x1_b1 << 2;
	
//Clock 5
//X0*(2-X0*B)
assign x1_c = x0_4 * x1_b2;
//first only keep the 8 MSB's of the last round and shift if necessary
always@(posedge clk)
begin
   x1 <= x1_c[15] ? x1_c[15:8] : x1_c[14] ? x1_c[14:7] : x1_c[13:6];
	x1_2 <= x1;
	x1_3 <= x1_2;
	x1_4 <= x1_3;
end
////////////////////////////////
//         2nd iteration      //
////////////////////////////////

//Clock 6
//X1 * B
always@(posedge clk)
   x2_a <= x1 * sj[4][15:8];
//2 - X1*B
//Clock 7
always@(posedge clk)
   x2_b1 <= (17'b10000000000000000 - {1'b0,x2_a});
//and shift as necessary
//Clock 8
always@(posedge clk)
   x2_b2 <= x2_b1[16] ? x2_b1 : x2_b1[15] ? x2_b1 << 1 : x2_b1 << 2;
//Clock 9
//X0*(2-X0*B)
assign x2_c = x1_4 * x2_b2;
//keep only the 16 MSB of the last round and shift as necessary
always@(posedge clk)
begin
   x2 <= x2_c[24] ? x2_c[24:9] : x2_c[23] ? x2_c[23:8] : x2_c[22:7];
	x2_2 <= x2;
	x2_3 <= x2_2;
	x2_4 <= x2_3;
end
//////////////////////////////////
//   3rd Iteration              //
//////////////////////////////////
//Clock 10
//X2 * B
always@(posedge clk)
   x3_a <= x2 * sj[8];

//Clock 11
//2 - X2*B
always@(posedge clk)
   x3_b1 <= (33'b100000000000000000000000000000000 - {1'b0,x3_a});
//and shift as necessary
//Clock 12
always@(posedge clk)
   x3_b2 <= x3_b1[32] ? x3_b1 : x3_b1[31] ? x3_b1 << 1 : x3_b1 << 2;
//X0 * (2-X0*B)
//Clock 13
assign x3_c = x2_4 * x3_b2;
//shift x3 as necessary
always@(posedge clk)
begin
   x3[47:0] <= x3_c[48] ? x3_c[48:1] : x3_c[47] ? x3_c[47:0] : {x3_c[46:0],1'b0};
end

//calculate and pipeline the exponent
always@(posedge clk)
   tmp_src <= selected_src[63:0];

always@(posedge clk)
   begin
	   exponent_1 <= (tmp_src[47:40]==8'b10000000) ? (tmp_src[62] ? (~(tmp_src[62:48]-15'b10) + 15'b1) : (~(tmp_src[62:48]+15'b10) + 15'b1)) : (tmp_src[62] ? (~(tmp_src[62:48]-15'b1) + 15'b1) : (~(tmp_src[62:48]+15'b1) + 15'b1)) ;
		exponent_2 <= exponent_1;
		exponent_3 <= exponent_2;
		exponent_4 <= exponent_3;
		exponent_5 <= exponent_4;
		exponent_6 <= exponent_5;
		exponent_7 <= exponent_6;
		exponent_8 <= exponent_7;
		exponent_9 <= exponent_8;
		exponent_10 <= exponent_9;
		exponent_11 <= exponent_10;
		exponent_12 <= exponent_11;
	end

//pipeline the sign

always@(posedge clk)
   begin
      sign[0]    <= selected_src[63];
		sign[12:1] <= sign[11:0];
   end
	
	
	
endmodule
