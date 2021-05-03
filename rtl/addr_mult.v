//******************************************
//       ADDRESS Multiply UNIT
//******************************************
//
//It takes 6 time units to produce a 24-bit result. No overflow is detected.
//If I add 4 partial products per cycle, it should work fine.

module addr_mult(i_aj, i_ak, clk, o_result);


input wire clk;
input wire [23:0] i_aj;
input wire [23:0] i_ak;

output reg [23:0] o_result;

reg [23:0] aj_0;
reg [23:0] ak_0;
reg [23:0] aj_1;
reg [23:0] ak_1;
reg [23:0] aj_2;
reg [23:0] ak_2;
reg [23:0] aj_3;
reg [23:0] ak_3;
reg [23:0] aj_4;
reg [23:0] ak_4;

reg [23:0] temp0;
reg [23:0] temp1;
reg [23:0] temp2;
reg [23:0] temp3;
reg [23:0] temp4;

wire [23:0] PP0;
wire [23:0] PP1;
wire [23:0] PP2;
wire [23:0] PP3;
wire [23:0] PP4;
wire [23:0] PP5;
wire [23:0] PP6;
wire [23:0] PP7;
wire [23:0] PP8;
wire [23:0] PP9;
wire [23:0] PP10;
wire [23:0] PP11;
wire [23:0] PP12;
wire [23:0] PP13;
wire [23:0] PP14;
wire [23:0] PP15;
wire [23:0] PP16;
wire [23:0] PP17;
wire [23:0] PP18;
wire [23:0] PP19;
wire [23:0] PP20;
wire [23:0] PP21;
wire [23:0] PP22;
wire [23:0] PP23;


assign PP0 = i_aj[0] ? i_ak[23:0] : 24'b0;
assign PP1 = PP0 + (i_aj[1] ? (i_ak[23:0] << 1) : 24'b0);
assign PP2 = PP1 + (i_aj[2] ? (i_ak[23:0] << 2) : 24'b0);
assign PP3 = PP2 + (i_aj[3] ? (i_ak[23:0] << 3) : 24'b0);
/*
assign PP3 = i_ak * i_aj[3:0];
*/
assign PP4 = temp0[23:0] + (aj_0[4] ? (ak_0[23:0] << 4) : 24'b0);
assign PP5 = PP4 + (aj_0[5] ? (ak_0[23:0] << 5) : 24'b0);
assign PP6 = PP5 + (aj_0[6] ? (ak_0[23:0] << 6) : 24'b0);
assign PP7 = PP6 + (aj_0[7] ? (ak_0[23:0] << 7) : 24'b0);
/*
assign PP7 = temp0 + ((ak_0 << 4) * aj_0[7:4]);
*/

assign PP8 = temp1[23:0] + (aj_1[8] ? (ak_1[23:0] << 8) : 24'b0);
assign PP9 = PP8 + (aj_1[9] ? (ak_1[23:0] << 9) : 24'b0);
assign PP10 = PP9 + (aj_1[10] ? (ak_1[23:0] << 10) : 24'b0);
assign PP11 = PP10 + (aj_1[11] ? (ak_1[23:0] << 11) : 24'b0);

//assign PP11 = temp1 + ((ak_1 << 8) * aj_1[11:8]);


assign PP12 = temp2[23:0] + (aj_2[12] ? (ak_2[23:0] << 12) : 24'b0);
assign PP13 = PP12 + (aj_2[13] ? (ak_2[23:0] << 13) : 24'b0);
assign PP14 = PP13 + (aj_2[14] ? (ak_2[23:0] << 14) : 24'b0);
assign PP15 = PP14 + (aj_2[15] ? (ak_2[23:0] << 15) : 24'b0);

//assign PP15 = temp2 + ((ak_2 << 12) * aj_2[15:12]);


assign PP16 = temp3[23:0] + (aj_3[16] ? (ak_3[23:0] << 16) : 24'b0);
assign PP17 = PP16 + (aj_3[17] ? (ak_3[23:0] << 17) : 24'b0);
assign PP18 = PP17 + (aj_3[18] ? (ak_3[23:0] << 18) : 24'b0);
assign PP19 = PP18 + (aj_3[19] ? (ak_3[23:0] << 19) : 24'b0);

//assign PP19 = temp3 + ((ak_3 << 16) * aj_3[19:16]);

assign PP20 = temp4[23:0] + (aj_4[20] ? (ak_4[23:0] << 20) : 24'b0);
assign PP21 = PP20 + (aj_4[21] ? (ak_4[23:0] << 21) : 24'b0);
assign PP22 = PP21 + (aj_4[22] ? (ak_4[23:0] << 22) : 24'b0);
assign PP23 = PP22 + (aj_4[23] ? (ak_4[23:0] << 23) : 24'b0);

//assign PP23 = temp4 + ((ak_4 << 20) * aj_4[23:20]);

always@(posedge clk)
begin
	ak_0 <= i_ak;
	ak_1 <= ak_0;
	ak_2 <= ak_1;
	ak_3 <= ak_2;
	ak_4 <= ak_3;
	aj_0 <= i_aj;
	aj_1 <= aj_0;
	aj_2 <= aj_1;
	aj_3 <= aj_2;
	aj_4 <= aj_3;
	
   temp0    <= PP3;
   temp1    <= PP7;
   temp2    <= PP11;
   temp3    <= PP15;
   temp4    <= PP19;
   o_result <= PP23;
end



endmodule
