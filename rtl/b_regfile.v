//This is a parameterizable register file


//////////////////////////////////////////////////////////////////
//        Secondary Address Register File                       //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This block contains one 64 entry, 24-bit register file used
//for the Cray-1A's 'secondary' address registers

module b_regfile (clk,
                  i_jk_addr,
                  o_jk_data,
                  i_wr_addr,
                  i_wr_data,
                  i_wr_en,
						i_cur_p,
						i_rtn_jump);

parameter WIDTH = 24;
parameter DEPTH = 64;
parameter LOGDEPTH = 6;


input  wire                clk;
input  wire [LOGDEPTH-1:0] i_jk_addr;
output reg  [WIDTH-1:0]    o_jk_data;
input  wire [LOGDEPTH-1:0] i_wr_addr;
input  wire [WIDTH-1:0]    i_wr_data;
input  wire                i_wr_en;
input  wire [WIDTH-1:0]    i_cur_p;
input  wire                i_rtn_jump;

reg [WIDTH-1:0] data [DEPTH-1:0];     //the actual registers

wire [WIDTH-1:0] wr_addr;

assign wr_addr = i_rtn_jump ? 6'b0 : i_wr_addr;


//write a register
always@(posedge clk)
   if(i_wr_en || i_rtn_jump)
      data[wr_addr] <= i_rtn_jump ? i_cur_p : i_wr_data;


//read registers
always@(posedge clk)
   o_jk_data <= data[i_jk_addr];

endmodule
