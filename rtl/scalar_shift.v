//******************************************
//            Scalar Shift Unit
//******************************************
//
//The scalar shift unit shifts the entire 64-bit
//contents of an S-register or shifts the double 
//128-bit contents of two concatenated S registers.
//Shift counts are obtained from an A register or
//from the jk portion of the instruction. Shifts 
//are end off with zero fill. For a double-shift,
//a circular shift is effected if the shift count
//does not exceed 64 and the i and j designators
//are equal and non-zero.

//The scalar shift unit executes instructions 052
//through 057. Single-register shift instructions,
// 052 through 055, are executed in two clock
//periods. Double-register shift instructions, 056
//and 057, are executed in three clock periods.

//{g[3:0],h[2:0],i[2:0],jk[5:0]}
//g,h==opcode, i==oprnd and result reg, jk==shift, mask count

//052ijk == Shift (Si) left jk places and enters the result into S0
//053ijk == Shift (Si) right by 64-jk places and enters the result in S0
//054ijk == Shift (Si) left jk places and enters the result into Si
//055ijk == Shift (Si) right by 64-jk places and enters the result into Si


//056ijk == Shift (Si) and (Sj) left by (Ak) places to Si
//057ijk == Shift (Sj) and (Si) right by (Ak) places to Si

//Hold issue conditions:
//      034-037 in process
//      Exchange in process
//      S register access conflict
//      Si reserved
//      S0 reserved (052 and 053 only)

//Execution time
//      for 052, 053, S0 ready - 2 CPs
//      for 054, 055, Si ready - 2 CPs
//      for 056, 057 - 3 CPs
//      Instruction issue - 1 CP

module scalar_shift(clk, i_si, i_sj, i_ak, i_instr, i_j, i_k, o_result);

    input wire [63:0] i_si;
    input wire [63:0] i_sj;
    input wire [23:0] i_ak;
    input wire [6:0]  i_instr;
    input wire [2:0]  i_j;
    input wire [2:0]  i_k;
    input wire clk;
    output wire [63:0] o_result;

    reg [6:0]  temp_instr0;
    reg [6:0]  temp_instr1;
    reg [63:0] temp_sj;
    reg [63:0] temp_si;
    reg [23:0] temp_ak;
    reg [5:0]  temp_jk;
    reg [63:0] result_s;
    reg [127:0] result_d1_l;
    reg [127:0] result_d1_r;
    reg [63:0] result_d;
    


//we should never be able to issue conflicting instructions back to back, so this should be fine
assign o_result = (temp_instr1[6:1]==6'b010111) ? result_d[63:0] : result_s[63:0];

always@(posedge clk)
begin
    temp_instr0[6:0] <= i_instr[6:0];
    temp_instr1[6:0] <= temp_instr0[6:0];
    temp_si[63:0]    <= i_si[63:0];
    temp_sj[63:0]    <= i_sj[63:0];
    temp_ak[23:0]    <= i_ak[23:0];
    temp_jk[5:0]     <= {i_j[2:0],i_k[2:0]};
    case(temp_instr0[1:0])
        2'b10:result_s[63:0] <= temp_si[63:0] << temp_jk;           //052ijk 
        2'b11:result_s[63:0] <= temp_si[63:0] >> (~temp_jk + 1);    //053ijk
        2'b00:result_s[63:0] <= temp_si[63:0] << temp_jk;           //054ijk
        2'b01:result_s[63:0] <= temp_si[63:0] >> (~temp_jk + 1);    //055ijk
    endcase

    result_d1_l[127:0] <= {temp_si[63:0],temp_sj[63:0]} << temp_ak[6:0];
    result_d1_r[127:0] <= {temp_sj[63:0],temp_si[63:0]} >> temp_ak[6:0]; 
    //for some reason, if A0 is selected (for Ak), it should shift by one position - page 4-37 in manual
    //and (Sj) = 0 if j=0
    result_d[63:0] <= temp_instr0[0] ? result_d1_r[127:64] : result_d1_l[127:64];
end

endmodule
