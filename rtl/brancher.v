//******************************************
//       Branch Handling Block
//******************************************
//
//This block handles all of the test/branch
//instructions. 
//
module brancher(clk,
                i_cip,
					 i_cip_vld,
					 i_lip,
					 i_lip_vld,
					 i_a0_neg,
					 i_a0_pos,
					 i_a0_zero,
					 i_a0_nzero,
					 i_a0_busy,
					 i_s0_neg,
					 i_s0_pos,
					 i_s0_zero,
					 i_s0_nzero,
					 i_s0_busy,
					 i_bjk,
					 o_branch_type,
					 o_branch_issue,
					 o_take_branch,
					 o_rtn_jump,
					 o_nxt_p);
					 
input wire        clk;
input wire [15:0] i_cip;
input wire        i_cip_vld;
input wire [15:0] i_lip;
input wire        i_lip_vld;
input wire        i_a0_neg;
input wire        i_a0_pos;
input wire        i_a0_zero;
input wire        i_a0_nzero;
input wire        i_a0_busy;
input wire        i_s0_neg;
input wire        i_s0_pos;
input wire        i_s0_zero;
input wire        i_s0_nzero;
input wire        i_s0_busy;
input wire [23:0] i_bjk;
output wire       o_branch_type;
output wire       o_branch_issue;
output wire       o_rtn_jump;
output wire       o_take_branch;
output wire[23:0] o_nxt_p;



reg [6:0]   instr;
reg [6:0]   instr2;
reg         branch_condition;
wire [24:0] ijkm;
wire        delay;

//detect if it's a branch instruction
assign o_branch_type = (i_cip[15:12]==4'b0001) | (i_cip[15:9]==7'o005) | (i_cip[15:9]==7'o006) | (i_cip[15:9]==7'o007);

assign o_branch_issue = o_branch_type && delay && i_cip_vld && i_lip_vld && (((i_cip[15:11]==5'b00010) && !i_a0_busy) || ((i_cip[15:11]==5'b00011) && !i_s0_busy) || ((i_cip[15:9]==7'o006) || (i_cip[15:9]==7'o005) || (i_cip[15:9]==7'o007)));

assign o_take_branch  = o_branch_issue && branch_condition;

assign o_rtn_jump = o_branch_type && o_branch_issue && (i_cip[15:9]==7'o007);

assign o_nxt_p = (instr==7'o005) ? i_bjk : ijkm[23:0]; //branch to (Bjk) or ijkm, depending on the instruction

assign ijkm = {i_cip[8:0],i_lip};   //this is a 25-bit field - the lower 24 bits are the address that we branch to


//This is another one of those weird timing things. For some reason,
// all branch instructions take 5 clock cycles to execute. I'm really
// not sure what it's doing during that time, but whatever, I didn't
// design it. This delay makes the 'instruction issue' part of the
// branch take 5 clock cycles.
assign delay=(instr2==i_cip[15:9]);  //just tells us that i_cip has been stalled for 1 cycle

always@(posedge clk)
begin
   instr <= i_cip[15:9];
	instr2 <= instr;
end



//Should we actually branch?
always@*
   case(instr) 
	   7'o005: branch_condition = 1'b1;       //branch to (Bjk)
		7'o006: branch_condition = 1'b1;       //branch to low 24 bits of ijkm
		7'o007: branch_condition = 1'b1;       //Return Jump to low 24 bits of ijkm; Set B00=P
		7'o010: branch_condition = i_a0_zero;  //branch to ijkm if (A0)==0
		7'o011: branch_condition = i_a0_nzero; //branch to ijkm if (A0)!=0
		7'o012: branch_condition = i_a0_pos;   //branch to ijkm if (A0) positive
		7'o013: branch_condition = i_a0_neg;   //branch to ijkm if (A0) negative
		7'o014: branch_condition = i_s0_zero;  //branch to ijkm if (S0)==0
		7'o015: branch_condition = i_s0_nzero; //branch to ijkm if (S0)!=0
		7'o016: branch_condition = i_s0_pos;   //branch to ijkm if (S0) positive
		7'o017: branch_condition = i_s0_neg;   //branch to ijkm if (S0) negative
		default: branch_condition = 1'b0;
	endcase
	
	
	
endmodule