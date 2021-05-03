//////////////////////////////////////////////////////////////////
//        Cray A-Register Scheduler Look-up Table               //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains the look-up tables used to figure out how
//many cycles until the result will be available, and which
//functional unit the result is available from.
module a_res_lut(i_instr, o_delay, o_src, o_a_dest_en);
	input wire [6:0] i_instr;
	output reg [3:0] o_delay;
   output reg [3:0] o_src;
	output wire o_a_dest_en;


localparam IMM      = 4'b0000,     //immediate
           COMP_IMM = 4'b0001,	   //complement of immediate
	        SIMM     = 4'b0010,     //short immediate
	        S_BUS    = 4'b0011,     //transmit (Sj) to Ai
	        B_BUS    = 4'b0100,     //transmit (Bjk) to Ai
	        S_POP    = 4'b0101,     //scalar population count
	        A_ADD    = 4'b0110,     //address add
	        A_MULT   = 4'b0111,     //address multiply
	        A_BUS    = 4'b1000,     //transmit (Ak) to Si
	        CHANNEL  = 4'b1001,     //real time clock
	        MEM      = 4'b1010,     //memory
   	     NONE     = 4'b1011;

//Check if we're writing something to an A register
assign o_a_dest_en = ((i_instr[6:3]==4'b0010)||(i_instr[6:2]==5'b00110)) && 
                     !(i_instr==7'o025) || (i_instr[6:3]==4'b1000);

always@*
begin
   case(i_instr)
      7'o020: o_delay = 4'd1;
      7'o021: o_delay = 4'd1;
      7'o022: o_delay = 4'd1;
      7'o023: o_delay = 4'd1;
      7'o024: o_delay = 4'd1;
      7'o026: o_delay = 4'd4;
      7'o027: o_delay = 4'd3;
      7'o030: o_delay = 4'd2;
      7'o031: o_delay = 4'd2;
      7'o032: o_delay = 4'd6;
      7'o033: o_delay = 4'd4;
      7'o100: o_delay = 4'd11;
      7'o101: o_delay = 4'd11;
      7'o102: o_delay = 4'd11;
      7'o103: o_delay = 4'd11;
      7'o104: o_delay = 4'd11;
      7'o105: o_delay = 4'd11;
      7'o106: o_delay = 4'd11;
      7'o107: o_delay = 4'd11;
      default: o_delay= 4'd0;
   endcase
end

always@*
begin
   case(i_instr)
      7'o020: o_src = IMM;
      7'o021: o_src = COMP_IMM;
      7'o022: o_src = SIMM;
      7'o023: o_src = S_BUS;
      7'o024: o_src = B_BUS;
      7'o026: o_src = S_POP;
      7'o027: o_src = S_POP;
      7'o030: o_src = A_ADD;
      7'o031: o_src = A_ADD;
      7'o032: o_src = A_MULT;
      7'o033: o_src = CHANNEL;
      7'o100: o_src = MEM;
      7'o101: o_src = MEM;
      7'o102: o_src = MEM;
      7'o103: o_src = MEM;
      7'o104: o_src = MEM;
      7'o105: o_src = MEM;
      7'o106: o_src = MEM;
      7'o107: o_src = MEM;
      default: o_src= NONE;
   endcase
end
endmodule
