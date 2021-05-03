//Cray-1 top-level 



//////////////////////////////////////////////////////////////////
//        Cray CPU Top-level                                    //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the top-level for the Cray-1A CPU block. It instantiates
//the primary "functional unit" block, as well as the 4 x 64-parcel
//instruction buffers.

module cray_top(clk,
                rst,
					 o_mem_addr,
					 o_mem_wr_data,
					 i_mem_rd_data,
					 i_mem_vld,
					 o_mem_wr_en,
					 o_mem_ce);


input  wire        clk;
input  wire        rst;


output wire [21:0] o_mem_addr;
input  wire [63:0] i_mem_rd_data;
input  wire        i_mem_vld;
output wire [63:0] o_mem_wr_data;
output wire        o_mem_wr_en;
output wire        o_mem_ce;



//instruction buffer singals
wire        instr_buf_mem_ce;
wire [21:0] instr_buf_mem_addr;
wire [63:0] instr_buf_mem_data;
wire instr_buf_mem_vld;

//functional unit signals
wire [21:0] fu_mem_addr;
wire [63:0] fu_mem_rd_data;
wire [63:0] fu_mem_wr_data;
wire fu_mem_wr_en;
wire fu_mem_ce;


wire [23:0] p_addr;
wire [15:0] nip_nxt;
wire [63:0] word_nxt;
wire        nip_vld;
wire        clear_ibufs;
reg         last_mem_winner;

localparam INSTR_BUF = 1'b1,
           FUNC = 1'b0;
			  
//assign the memory interface
assign o_mem_addr    = fu_mem_ce ? fu_mem_addr : instr_buf_mem_addr;
assign o_mem_wr_data = fu_mem_wr_data;
assign o_mem_wr_en   = fu_mem_wr_en;
assign o_mem_ce      = fu_mem_ce || instr_buf_mem_ce;

assign instr_buf_mem_data = i_mem_rd_data;
assign fu_mem_rd_data     = i_mem_rd_data;

//block instruction reads when a functional unit is accessing memory (I think this is implicit anyway)
assign instr_buf_mem_vld = (last_mem_winner==INSTR_BUF) && i_mem_vld;

//let's store the last winner for the memory interface
always@(posedge clk)
   last_mem_winner <= !fu_mem_ce;

/////////////////////////////////////////////////
//     4 x 64-parcel Instruction buffers       //
/////////////////////////////////////////////////
i_buf instr_buf(.clk(clk), 
                .rst(rst || clear_ibufs), 
                .i_p_addr(p_addr),
                .o_nip_nxt(nip_nxt),
					 .o_word_nxt(word_nxt),
                .o_nip_vld(nip_vld),
                .o_mem_ce(instr_buf_mem_ce),
                .o_mem_addr(instr_buf_mem_addr),
                .i_mem_data(instr_buf_mem_data),
                .i_mem_vld(instr_buf_mem_vld));


//////////////////////////////////////////////////
//      Functional Units and Register Files     //
//////////////////////////////////////////////////

func_top furf(.clk(clk),
              .rst(rst),
              .i_nip_nxt(nip_nxt),
				  .i_word_nxt(word_nxt),
              .i_nip_vld(nip_vld),
				  .o_clear_ibufs(clear_ibufs),
              .o_p_addr(p_addr),
				  .o_mem_addr(fu_mem_addr),
				  .i_data_from_mem(fu_mem_rd_data),
				  .o_data_to_mem(fu_mem_wr_data),
				  .o_mem_wr_en(fu_mem_wr_en),
				  .o_mem_ce(fu_mem_ce));


endmodule
