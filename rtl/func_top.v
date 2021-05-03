//////////////////////////////////////////////////////////////////
//        Cray Functional Unit Top-level                        //
//        Author: Christopher Fenton                            //
//        Date:  8/8/23                                         //
//////////////////////////////////////////////////////////////////
//
//This is the "functional unit" top-level block. It instantiates all
//of the register files (A, B, S, T and V), as well as all 13 functional
//units for computing (logical, math, etc.), and all of the logic to handle
//the program counter, branching, etc.
//
module func_top(clk, 
                rst,
                i_nip_nxt,
                i_word_nxt,
                i_nip_vld,
                o_p_addr,
					 o_clear_ibufs,
                o_mem_ce,
                o_mem_addr,
                i_data_from_mem,
                o_data_to_mem,
                o_mem_wr_en);


`include "cray_types.vh"
//system signals
input  wire clk;
input  wire rst;
input  wire [15:0] i_nip_nxt;
input  wire [63:0] i_word_nxt;      
input  wire        i_nip_vld;
output wire [23:0] o_p_addr;
output wire        o_clear_ibufs;
//memory interface
output wire         o_mem_ce;
output wire [21:0]  o_mem_addr;
input  wire [63:0]  i_data_from_mem;
output reg  [63:0]  o_data_to_mem;
output wire         o_mem_wr_en;


//Functional unit outputs
wire [23:0] a_poplz_out;       //24-bit output of scalar population/leading zero count
wire [23:0] a_mul_out;         //24-bit output of address multiply unit
wire [23:0] a_add_out;         //24-bit output of address adder
wire [23:0] a_imm_out;         //24-bit output of immediate values
wire [63:0] s_add_out;         //64-bit output of scalar adder output
wire [63:0] s_log_out;         //64-bit output of scalar logical unit
wire [63:0] s_shft_out;        //64-bit output of scalar shift unit
wire [63:0] s_const_out;       //64-bit output of Scalar constant generator / way to get data from A regs to scalar regs
wire [63:0] s_imm_out;         //64-bit output of immediate values
wire [63:0] f_add_out;         //64-bit output of floating point adder unit
wire [63:0] f_mul_out;         //64-bit output of floating point multiplier unit
wire [63:0] f_ra_out;          //64-bit output of floating point reciprocal approximation unit

wire vlog_busy;
wire vshift_busy;
wire vadd_busy;
wire fp_mul_busy;
wire fp_add_busy;
wire fp_ra_busy;
wire vpop_busy;
wire mem_busy;

wire [63:0] v_add_out;
wire [63:0] v_log_out;
wire [63:0] v_poppar_out;
wire [63:0] v_shft_out;

//vector control registers
reg [63:0]  vector_mask;
reg [6:0]   vector_length;

//scalar register file signals
wire [2:0]  s_j_addr;       //scalar read address
wire [2:0]  s_k_addr;
wire [2:0]  s_i_addr;
wire [2:0]  s_ex_addr;
wire [63:0] s_ex_data;
wire [63:0] s_j_data;       //scalar read data
wire [63:0] s_k_data;
wire [63:0] s_i_data;
reg  [63:0] s_wr_data;       //64-bit data input to scalar register file
wire s0_pos;
wire s0_neg;
wire s0_zero;
wire s0_nzero;
wire [7:0] s_res_mask;

wire [63:0] t_jk_data;
wire [5:0]  t_result_dest;
wire [5:0]  t_rd_addr;
wire [63:0] t_wr_data;
wire        t_result_en;


//address register file signals
wire [2:0]  a_j_addr;       //address read address
wire [2:0]  a_k_addr;
wire [2:0]  a_i_addr;
wire [2:0]  a_h_addr;
wire [2:0]  a_ex_addr;
wire [23:0] a_ex_data;
wire [23:0] a_j_data;       //address read data
wire [23:0] a_k_data;
wire [23:0] a_i_data;
wire [23:0] a_h_data;
wire [23:0] a_a0_data;
reg  [23:0] a_wr_data;       //24-bit data input to address register file
wire a0_pos;
wire a0_neg;
wire a0_zero;
wire a0_nzero;
wire [7:0] a_res_mask;

wire [23:0] b_jk_data;
wire [23:0] b_wr_data;
wire [5:0]  b_wr_addr;
wire [5:0]  b_rd_addr;



//branch unit signals
wire [23:0] branch_dest;
wire branch_type;
wire branch_issue;
wire take_branch;
wire rtn_jump;

//memory unit signals

wire [5:0] mem_b_rd_addr;
wire [5:0] mem_b_wr_addr;
wire       mem_b_wr_en;
wire [5:0] mem_t_rd_addr;
wire [5:0] mem_t_wr_addr;
wire [63:0] data_from_mem_to_regs;
wire        mem_type;
wire        mem_issue;
wire        mem_ce;
wire [63:0] data_to_mem;
wire        mem_wr_en;

//Exchange Package logic
reg [3:0] execution_mode;
reg [3:0] ex_pkg_cnt;

localparam EXECUTE      = 4'b0000,
           CLEAR_IBUF   = 4'b0001,
           FETCH_EX_PKG = 4'b0010,
           LOAD_WAIT    = 4'b0011,
           STORE_EX_PKG = 4'b0100,
           LOAD_EX_PKG  = 4'b0101,
			  DONE         = 4'b0110;

reg [7:0]  xa;
reg [7:0]  active_xa;
reg [17:0] base_address;
reg [17:0] limit_address;
reg [2:0]  mode;
reg [3:0]  flags;		

//Real Time Clock
reg [63:0]  real_time_clock;

//******************************************
//*           Instruction Issue            *
//*                Logic                   *
//******************************************

reg  [23:0] p_addr;
reg  [15:0] nip, lip, cip;
reg         nip_vld, lip_vld, cip_vld;

wire [6:0]  cip_instr;
wire [2:0]  cip_i, cip_j, cip_k, cip_h;
wire        issue_vld;
reg  [15:0] last_instr;
wire        two_parcel_nip;

//break out the current instruction parcel into fields
assign cip_instr = cip[15:9];
assign cip_i     = cip[8:6];
assign cip_j     = cip[5:3];
assign cip_k     = cip[2:0];
assign cip_h     = cip[11:9];

//A-type scheduler signals
wire [3:0]  a_result_src;
wire [3:0]  a_result_delay;
wire        a_result_en;
wire        a_wr_en;
wire [2:0]  a_result_dest;  //the a-register we're targeting
wire [2:0]  a_wr_addr;
wire        a_issue;
wire        a_type;
wire        a0_busy;

//S-type scheduler signals
wire [4:0]  s_result_src;
wire [3:0]  s_result_delay;
wire        s_result_en;
wire        s_wr_en;
wire [2:0]  s_result_dest;  //the s-register we're targeting
wire [2:0]  s_wr_addr;
wire        s_issue;
wire        s_type;
wire [7:0]  vreg_swrite;
wire        s0_busy;

//V-type scheduler signals
wire [3:0]  v_fu_delay;
wire [2:0]  v_fu;
wire [7:0]  vwrite_start;
wire [7:0]  vread_start;
wire [7:0]  vfu_start;
wire [7:0]  vreg_busy;
wire [7:0]  vreg_chain_n;
wire [7:0]  vfu_busy; 
wire [(64*8-1):0] v_rd_data;
wire        v_issue;
wire        v_type;					

wire        exchange_type;


//////////////////////////////////////////
//     Exchange Package Logic           //
//////////////////////////////////////////
//This block handles the operating "mode" of the CPU core. It's either running
//or context switching (exchanging 'exchange packages')

always@(posedge clk)
if(rst)
   execution_mode <= CLEAR_IBUF;
else
   case(execution_mode)
	   EXECUTE:    if(exchange_type)                    //execute normal instructions
                     execution_mode <= CLEAR_IBUF;		
      CLEAR_IBUF: execution_mode <= FETCH_EX_PKG;       //clear the instruction buffers
		FETCH_EX_PKG:if(i_nip_vld)                        //Wait while the XP is loaded into an instruction buffer
		               execution_mode <= LOAD_WAIT;
		LOAD_WAIT:execution_mode <= STORE_EX_PKG;           //FIXME: Wait until all instructions are finished executing
		STORE_EX_PKG:if(ex_pkg_cnt==4'b1111)
		             execution_mode <= LOAD_EX_PKG;          //Write back the context of the current process
      LOAD_EX_PKG: if(ex_pkg_cnt==4'b1111)
		             execution_mode <= DONE;
		DONE: execution_mode <= EXECUTE;
 default:execution_mode <= EXECUTE;
	endcase
	

assign o_clear_ibufs = (execution_mode == CLEAR_IBUF) || (execution_mode == DONE);

assign exchange_type = ((cip[15:9]==7'o000) || (cip[15:9]==7'o004)) && cip_vld;

//Increment the exchange package counter as we load in the package
always@(posedge clk)
   if(rst)
	   ex_pkg_cnt <= 4'b0;
   else if((execution_mode==STORE_EX_PKG) || (execution_mode==LOAD_EX_PKG))
	   ex_pkg_cnt <= ex_pkg_cnt + 1;
	else 
	   ex_pkg_cnt <= 4'b0;
		
//look up the appropriate A and S reg values to store them during the exchange sequence
assign a_ex_addr = ex_pkg_cnt[2:0];
assign s_ex_addr = ex_pkg_cnt[2:0];


//We want to store the current exchange address if we start an exchange operation
always@(posedge clk)
   if(rst)
	   active_xa <= 0;
   else if(execution_mode==EXECUTE)
	   active_xa <= xa;

//If we're in execute mode, address is controlled by program counter. Otherwise controlled
//by the exchange package management logic
assign o_p_addr = (execution_mode==EXECUTE) ? p_addr : {10'b0,active_xa,ex_pkg_cnt,2'b00};
                     
//The memory interface is controlled in a similar fashion:
always@*
   begin
	   if(execution_mode==EXECUTE)
         o_data_to_mem = data_to_mem;
		else case(ex_pkg_cnt)
		              4'b0000: o_data_to_mem = {16'b0,p_addr,a_ex_data};
				  4'b0001: o_data_to_mem = {16'b0,2'b0,base_address,4'b0,a_ex_data};
				  4'b0010: o_data_to_mem = {16'b0,2'b0,limit_address,1'b0,mode,a_ex_data};
				  4'b0011: o_data_to_mem = {16'b0,active_xa,vector_length,flags,a_ex_data};
				  4'b0100: o_data_to_mem = {40'b0,a_ex_data};
				  4'b0101: o_data_to_mem = {40'b0,a_ex_data};
				  4'b0110: o_data_to_mem = {40'b0,a_ex_data};
				  4'b0111: o_data_to_mem = {40'b0,a_ex_data};
				  default: o_data_to_mem = s_ex_data;
	   endcase
	end

//make sure to write the exchange package back before loading the new one
assign o_mem_wr_en = (execution_mode==EXECUTE) ? mem_wr_en : (execution_mode==STORE_EX_PKG);
assign o_mem_ce    = (execution_mode==EXECUTE) ? mem_ce  : (execution_mode==STORE_EX_PKG);


//Set up the base and limit registers
always@(posedge clk)
   if(rst)
      base_address <= 18'b0;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt==4'b0001))
      base_address <= i_word_nxt[45:28];

always@(posedge clk)
   if(rst)
      limit_address <= 18'h3FFFF;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt==4'b0010))
      limit_address <= i_word_nxt[45:28];

//and exchange address
always@(posedge clk)
   if(rst)
      xa <= 18'h0;
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt==4'b0011))
      xa <= i_word_nxt[47:40];


//1) accept the incoming data from the instruction buffers
always@(posedge clk)
   if(rst || (execution_mode == DONE))
	   begin
		   nip <= 16'b0;
			cip <= 16'b0;
			lip <= 16'b0;
			nip_vld <= 1'b0;
			cip_vld <= 1'b0;
			lip_vld <= 1'b0;
		end
   else if (i_nip_vld && issue_vld)
      begin
         nip <= two_parcel_nip ? 16'b0 : i_nip_nxt;
         lip <= i_nip_nxt;
         cip <= nip;
         lip_vld <= nip_vld;
         nip_vld <= (two_parcel_nip || take_branch) ? 1'b0 : 1'b1;
         cip_vld <= take_branch ? 1'b0 : nip_vld;
      end

//Two parcel instructions
assign two_parcel_nip = nip_vld && ((nip[15:10]==6'b000011)||   //006-007
                       (nip[15:12]==4'b0001)  ||   //010-017
 							  (nip[15:10]==6'b001000)||   //020-021
							  (nip[15:10]==6'b010000)||   //040-041
							  (nip[15:14]==2'b10)) ;       //100-137

always@(posedge clk)
   last_instr <= cip;
	
	
	
	


//Track S-type related reservations, destination data and if we can issue or not
s_scheduler ssched(.clk(clk),
            .rst(rst),
            .i_cip(cip),
				.i_cip_vld(cip_vld),
            .i_issue_vld(issue_vld),
            .o_s_issue(s_issue),
            .o_s_result_en(s_result_en),
            .o_s_result_src(s_result_src),
            .o_s_result_dest(s_result_dest),
            .o_s_type(s_type),
				.i_vreg_busy(vreg_busy),
				.o_vreg_write(vreg_swrite),
				.o_s0_busy(s0_busy),
				.o_s_res_mask(s_res_mask));

//Now let's get the correct data to write
always@*
begin
   if(execution_mode==EXECUTE)
        case(s_result_src[4:0])
                SBUS_IMM:     s_wr_data = s_imm_out;
                SBUS_COMP_IMM:s_wr_data = s_imm_out;
                SBUS_S_LOG:   s_wr_data = s_log_out;
                SBUS_S_SHIFT: s_wr_data = s_shft_out;
                SBUS_S_ADD:   s_wr_data = s_add_out;
                SBUS_FP_ADD:  s_wr_data = f_add_out;
                SBUS_FP_MULT: s_wr_data = f_mul_out;
                SBUS_FP_RA:   s_wr_data = f_ra_out;
                SBUS_CONST_GEN:s_wr_data= s_const_out;
                SBUS_RTC:     s_wr_data = real_time_clock;
                SBUS_V_MASK:  s_wr_data = vector_mask;
                SBUS_T_BUS:   s_wr_data = t_jk_data;
                SBUS_V0:      s_wr_data = v_rd_data[63:0];
		    SBUS_V1:      s_wr_data = v_rd_data[127:64];
		    SBUS_V2:      s_wr_data = v_rd_data[191:128];
		    SBUS_V3:      s_wr_data = v_rd_data[255:192];
		    SBUS_V4:      s_wr_data = v_rd_data[319:256];
		    SBUS_V5:      s_wr_data = v_rd_data[383:320];
		    SBUS_V6:      s_wr_data = v_rd_data[447:384];
		    SBUS_V7:      s_wr_data = v_rd_data[511:448];
                SBUS_MEM:     s_wr_data = data_from_mem_to_regs;
                default:      s_wr_data = 64'b0;
        endcase
	else
	   s_wr_data = i_word_nxt;
end

assign s_wr_en   = (execution_mode==EXECUTE) ? s_result_en   : ((execution_mode==LOAD_EX_PKG) && ex_pkg_cnt[3]);
assign s_wr_addr = (execution_mode==EXECUTE) ? s_result_dest : s_ex_addr;

 
//Track A-type related reservations, destination data and if we can issue or not
a_scheduler asched(.clk(clk),
                   .rst(rst),
                   .i_cip(cip),
			 .i_cip_vld(cip_vld),
			 .i_lip_vld(lip_vld),
                   .i_issue_vld(issue_vld),
                   .o_a_issue(a_issue),
                   .o_a_result_en(a_result_en),
                   .o_a_result_src(a_result_src),
                   .o_a_result_dest(a_result_dest),
                   .o_a_type(a_type),
			 .o_a0_busy(a0_busy),
			 .o_a_res_mask(a_res_mask));


always@*
begin
   if(execution_mode == EXECUTE)
	   case(a_result_src[3:0])
		ABUS_IMM:     a_wr_data = a_imm_out;
		ABUS_COMP_IMM:a_wr_data = a_imm_out;
		ABUS_SIMM:    a_wr_data = {18'b0,last_instr[5:0]};
		ABUS_S_BUS:   a_wr_data = a_imm_out;
		ABUS_B_BUS:   a_wr_data = b_jk_data;
		ABUS_S_POP:   a_wr_data = a_poplz_out;
		ABUS_A_ADD:   a_wr_data = a_add_out;
		ABUS_A_MULT:  a_wr_data = a_mul_out;
		ABUS_CHANNEL: a_wr_data = 24'b0;
		ABUS_MEM:     a_wr_data = data_from_mem_to_regs[23:0];
		default:      a_wr_data = 24'b0;
	   endcase
	else
	   a_wr_data = i_word_nxt[23:0];
end

assign a_wr_en = (execution_mode==EXECUTE) ? a_result_en : ((execution_mode==LOAD_EX_PKG) && !ex_pkg_cnt[3]);
assign a_wr_addr = (execution_mode==EXECUTE) ? a_result_dest : a_ex_addr;

//Track V-type instructions
v_scheduler vsched(.i_cip(cip),
            .i_cip_vld(cip_vld), 
				.o_fu_delay(v_fu_delay), 
				.o_fu(v_fu), 
				.o_vwrite_start(vwrite_start),
				.o_vread_start(vread_start), 
				.o_vfu_start(vfu_start),
				.o_v_issue(v_issue),
				.i_vreg_busy(vreg_busy),
				.i_vreg_chain_n(vreg_chain_n),
				.i_vfu_busy(vfu_busy));
/*
localparam VLOG      = 3'b000,   //vector logical
           VSHIFT    = 3'b001,	 //vector shift
			  VADD      = 3'b010,
	        FP_MUL    = 3'b011,   //FP multiply
	        FP_ADD    = 3'b100,   //FP adder 
	        FP_RA     = 3'b101,   //FP recip. approx.
	        VPOP      = 3'b110,   //vector pop count / parity
	         MEM      = 3'b111;
				
				vfu_start
*/
assign vfu_busy[0] = vlog_busy;
assign vfu_busy[1] = vshift_busy;
assign vfu_busy[2] = vadd_busy;
assign vfu_busy[3] = fp_mul_busy;
assign vfu_busy[4] = fp_add_busy;
assign vfu_busy[5] = fp_ra_busy;
assign vfu_busy[6] = vpop_busy;
assign vfu_busy[7] = mem_busy;
assign v_type = (cip[15:14] == 2'b11);

assign mem_busy  = o_mem_ce;

//check if it's free to issue
						
assign issue_vld = (s_issue && s_type) || 
                   (a_issue && a_type) ||
						 (v_issue && v_type) ||
						 (branch_issue && branch_type) ||
						 (mem_issue && mem_type) ||
						 exchange_type ||
						 !(s_type || a_type || v_type || branch_type || mem_type || exchange_type);             //just tie high for now



//////////////////////////////////////////////////
//           Register Files                     //
//////////////////////////////////////////////////

//The eight vector register files
vec_regfile_hard v0(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[63:0]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[0]),
					.i_vwrite_start(vwrite_start[0]),
					.i_swrite_start(vreg_swrite[0]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[0]),
					.o_chain_n(vreg_chain_n[0]));

vec_regfile_hard v1(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[127:64]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[1]),
					.i_vwrite_start(vwrite_start[1]),
					.i_swrite_start(vreg_swrite[1]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[1]),
					.o_chain_n(vreg_chain_n[1]));

vec_regfile_hard v2(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[191:128]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[2]),
					.i_vwrite_start(vwrite_start[2]),
					.i_swrite_start(vreg_swrite[2]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[2]),
					.o_chain_n(vreg_chain_n[2]));

vec_regfile_hard v3(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[255:192]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[3]),
					.i_vwrite_start(vwrite_start[3]),
					.i_swrite_start(vreg_swrite[3]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[3]),
					.o_chain_n(vreg_chain_n[3]));

vec_regfile_hard v4(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[319:256]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[4]),
					.i_vwrite_start(vwrite_start[4]),
					.i_swrite_start(vreg_swrite[4]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[4]),
					.o_chain_n(vreg_chain_n[4]));

vec_regfile_hard v5(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[383:320]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
               .i_vread_start(vread_start[5]),
					.i_vwrite_start(vwrite_start[5]),
					.i_swrite_start(vreg_swrite[5]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[5]),
					.o_chain_n(vreg_chain_n[5]));

vec_regfile_hard v6(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[447:384]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
                              .i_vread_start(vread_start[6]),
					.i_vwrite_start(vwrite_start[6]),
					.i_swrite_start(vreg_swrite[6]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[6]),
					.o_chain_n(vreg_chain_n[6]));

vec_regfile_hard v7(.clk(clk),
               .rst(rst),
					.o_rd_data(v_rd_data[511:448]),
					.i_sbus(s_j_data),
					.i_v_add(v_add_out),
					.i_v_log(v_log_out),
					.i_v_shift(v_shft_out),
					.i_v_poppar(v_poppar_out),
					.i_fp_add(f_add_out),
					.i_fp_mult(f_mul_out),
					.i_fp_ra(f_ra_out),
					.i_mem(data_from_mem_to_regs),
                              .i_vread_start(vread_start[7]),
					.i_vwrite_start(vwrite_start[7]),
					.i_swrite_start(vreg_swrite[7]),
					.i_vector_length(vector_length),
					.i_vector_mask(vector_mask),
					.i_ak(a_k_data),
					.i_fu_time(v_fu_delay),
					.i_fu(v_fu),
					.o_busy(vreg_busy[7]),
					.o_chain_n(vreg_chain_n[7]));

s_regfile #(.WIDTH(64),.DEPTH(8),.LOGDEPTH(3))
        s_rf(.clk(clk),
		 .rst(rst),
             .i_j_addr(cip_j),
             .i_k_addr(cip_k),
             .i_i_addr(cip_i),
             .i_ex_addr(s_ex_addr),
             .o_ex_data(s_ex_data),
             .o_j_data(s_j_data),
             .o_k_data(s_k_data),
             .o_i_data(s_i_data),
             .i_wr_addr(s_wr_addr),
             .i_wr_data(s_wr_data),
             .i_wr_en(s_wr_en),
             .o_s0_pos(s0_pos),
             .o_s0_neg(s0_neg),
             .o_s0_zero(s0_zero),
             .o_s0_nzero(s0_nzero));



t_regfile_hard #(.WIDTH(64),.DEPTH(64),.LOGDEPTH(6))
        t_rf(.clk(clk),
        .i_jk_addr(t_rd_addr),
        .o_jk_data(t_jk_data),
        .i_wr_addr(t_result_dest),
        .i_wr_data(t_wr_data),
        .i_wr_en(t_result_en));
		  
assign t_rd_addr = v_type ? mem_t_wr_addr : {cip_j,cip_k};

//We can accept data from the S reg-file or from memory
assign t_wr_data = (cip_instr==7'o075) ? s_i_data : data_from_mem_to_regs;

a_regfile #(.WIDTH(24),.DEPTH(8),.LOGDEPTH(3))
        A_rf(.clk(clk),
             .rst(rst),
             .i_j_addr(cip_j),
             .i_k_addr(cip_k),
             .i_i_addr(cip_i),
             .i_h_addr(cip_h),
             .i_ex_addr(a_ex_addr),
             .o_ex_data(a_ex_data),
             .o_j_data(a_j_data),
             .o_k_data(a_k_data),
             .o_i_data(a_i_data),
             .o_h_data(a_h_data),
             .o_a0_data(a_a0_data),
             .i_wr_addr(a_wr_addr),
             .i_wr_data(a_wr_data),
             .i_wr_en(a_wr_en),
             .o_a0_pos(a0_pos),
             .o_a0_neg(a0_neg),
             .o_a0_zero(a0_zero),
             .o_a0_nzero(a0_nzero));
		  

b_regfile #(.WIDTH(24),.DEPTH(64),.LOGDEPTH(6))
        b_rf(.clk(clk),
        .i_jk_addr(b_rd_addr),
	     .o_jk_data(b_jk_data),
        .i_wr_addr(b_wr_addr),
        .i_wr_data(b_wr_data),
        .i_wr_en(b_write_en),
		  .i_cur_p(p_addr),
		  .i_rtn_jump(rtn_jump));

//Figure out when and what we should write into the B register file
assign b_wr_addr  = (cip_instr==7'o025) ? {cip_j,cip_k} : mem_b_wr_addr;
assign b_wr_data  = (cip_instr==7'o025) ? a_i_data : data_from_mem_to_regs[23:0];
assign b_write_en = ((cip_instr==7'o025) && a_issue) || ((cip_instr==7'o034) && mem_b_wr_en );

//and figure out what address to read from
assign b_rd_addr = (cip_instr==7'o035) ? mem_b_rd_addr : {cip_j,cip_k};	  

//////////////////////////////////////////////////
//           Vector Units                       //
//////////////////////////////////////////////////


//Vector Addition unit
vector_add vadd(.clk(clk),           //system clock input
                .rst(rst),
                .i_start(vfu_start[2]),          //signal start of new vector operation
                .i_instr(cip_instr),          //7-bit instruction input
					 .i_vl(vector_length),
					 .i_j(cip_j),
					 .i_k(cip_k),
                .i_sj(s_j_data),  //64-bit sj input
                .i_v0(v_rd_data[63:0]),
                .i_v1(v_rd_data[127:64]),
                .i_v2(v_rd_data[191:128]),
                .i_v3(v_rd_data[255:192]),
                .i_v4(v_rd_data[319:256]),
                .i_v5(v_rd_data[383:320]),
                .i_v6(v_rd_data[447:384]),
                .i_v7(v_rd_data[511:448]),					 
                .o_result(v_add_out),        //64-bit output
					 .o_busy(vadd_busy));


//Vector Logical unit
vector_logical vlog(.clk(clk),               //system clock input
                    .rst(rst),
                    .i_start(vfu_start[0]),  //signal start of new vector operation
                    .i_instr(cip_instr),     //7-bit instruction input
						  .i_vl(vector_length),    //7-bit vector length
                    .i_i(cip_i),             //3-bit i input
                    .i_j(cip_j),             //3-bit j input
                    .i_k(cip_k),             //3-bit k input
                    .i_sj(s_j_data),         //64-bit sj input
                    .i_v0(v_rd_data[63:0]),
                    .i_v1(v_rd_data[127:64]),
                    .i_v2(v_rd_data[191:128]),
                    .i_v3(v_rd_data[255:192]),
                    .i_v4(v_rd_data[319:256]),
                    .i_v5(v_rd_data[383:320]),
                    .i_v6(v_rd_data[447:384]),
                    .i_v7(v_rd_data[511:448]),		
                    .i_vm(vector_mask),      //64-bit vector mask input
                    .o_result(v_log_out),    //64-bit output
						  .o_busy(vlog_busy));     //FU reserved signal


//Vector Population Count and parity unit	    
vector_pop_parity vpoppar(.clk(clk),        //system clock input
                          .rst(rst),
                          .i_start(vfu_start[6]),       //signal to start a new vector operation
								  .o_busy(vpop_busy),
								  .i_vl(vector_length),
                          .i_k(cip_k),           //3-bit k field input
								  .i_j(cip_j),
                          .i_v0(v_rd_data[63:0]),
                          .i_v1(v_rd_data[127:64]),
                          .i_v2(v_rd_data[191:128]),
                          .i_v3(v_rd_data[255:192]),
                          .i_v4(v_rd_data[319:256]),
                          .i_v5(v_rd_data[383:320]),
                          .i_v6(v_rd_data[447:384]),
                          .i_v7(v_rd_data[511:448]),		  
                          .o_result(v_poppar_out));     //64-bit output

//Vector Shift unit
wire [63:0] v_shft_vj_in;
wire [23:0] v_shft_ak_in;

vector_shift vshift(.clk(clk),                 //system clock input
                    .rst(rst),
                    .i_start(vfu_start[1]),    //signal start of new vector operation
                    .i_instr(cip_instr),       //7-bit instruction input
						  .i_vl(vector_length),      //7-bit vector length
                    .i_k(cip_k),               //3-bit k input
						  .i_j(cip_j),
                    .i_v0(v_rd_data[63:0]),
                    .i_v1(v_rd_data[127:64]),
                    .i_v2(v_rd_data[191:128]),
                    .i_v3(v_rd_data[255:192]),
                    .i_v4(v_rd_data[319:256]),
                    .i_v5(v_rd_data[383:320]),
                    .i_v6(v_rd_data[447:384]),
                    .i_v7(v_rd_data[511:448]),			
                    .i_ak(v_shft_ak_in),              //24-bit ak input
                    .o_result(v_shft_out),         //64-bit output
						  .o_busy(vshift_busy));


///////////////////////////////////////////////
//          Floating Point Units             //
///////////////////////////////////////////////


//Floating Point Addition unit
float_add  fadd  (.clk(clk),       //system clock input
                  .rst(rst),
                  .i_cip(cip),      //7-bit instruction input
						.i_vstart(vfu_start[4]),
						.i_vector_length(vector_length),
                  .i_v0(v_rd_data[63:0]),
                  .i_v1(v_rd_data[127:64]),
                  .i_v2(v_rd_data[191:128]),
                  .i_v3(v_rd_data[255:192]),
                  .i_v4(v_rd_data[319:256]),
                  .i_v5(v_rd_data[383:320]),
                  .i_v6(v_rd_data[447:384]),
                  .i_v7(v_rd_data[511:448]),
                  .i_sj(s_j_data),         //64-bit sj register input
                  .i_sk(s_k_data),         //64-bit sk register input
                  .o_result(f_add_out),       //64-bit output
						.o_busy(fp_add_busy),
                  .err());         //error output


//Floating Point Multiply unit
fast_float_mult fmult(.clk(clk),        //system clock input 
                 .rst(rst),
                 .i_cip(cip),       //current instruction parcel
					  .i_vstart(vfu_start[3]),
					  .i_vector_length(vector_length),
					  .i_v0(v_rd_data[63:0]),
                 .i_v1(v_rd_data[127:64]),
                 .i_v2(v_rd_data[191:128]),
                 .i_v3(v_rd_data[255:192]),
                 .i_v4(v_rd_data[319:256]),
                 .i_v5(v_rd_data[383:320]),
                 .i_v6(v_rd_data[447:384]),
                 .i_v7(v_rd_data[511:448]),
                 .i_sj(s_j_data),          //64-bit sj register input
                 .i_sk(s_k_data),          //64-bit sk register input
                 .o_result(f_mul_out),     //64-bit output
                 .o_busy(fp_mul_busy));

//Floating Point Reciprocal Approximation unit
float_recip frecip(.clk(clk),      //system clock input
                   .rst(rst),
						 .i_vstart(vfu_start[5]),
						 .i_vector_length(vector_length),
						 .i_v0(v_rd_data[63:0]),
                   .i_v1(v_rd_data[127:64]),
                   .i_v2(v_rd_data[191:128]),
                   .i_v3(v_rd_data[255:192]),
                   .i_v4(v_rd_data[319:256]),
                   .i_v5(v_rd_data[383:320]),
                   .i_v6(v_rd_data[447:384]),
                   .i_v7(v_rd_data[511:448]),
                   .i_sj(s_j_data),         //64-bit sj register input
                   .o_result(f_ra_out),    //64-bit output (14 cycles later)
						 .o_busy(fp_ra_busy));
						 

//////////////////////////////////////////////////
//           Scalar Units                       //
//////////////////////////////////////////////////

//Scalar Addition unit
scalar_add sadd(.clk(clk),           //system clock input
                .i_instr(cip_instr),          //7-bit instruction input
                .i_sj(s_j_data),             //64-bit sj input
                .i_sk(s_k_data),             //64-bit sk input
                .o_result(s_add_out));        //64-bit output


//Scalar Logical unit
scalar_logical slog(.clk(clk),       //system clock input
                    .i_instr(cip_instr),      //7-bit instruction input
                    .i_j(cip_j),          //3-bit j input
                    .i_k(cip_k),          //3-bit k input
                    .i_sj(s_j_data),         //64-bit sj input
                    .i_sk(s_k_data),         //64-bit sk input
                    .o_result(s_log_out));    //64-bit output


//Scalar Population Count and Leading-Zero Count unit
scalar_pop_lz spoplz(.clk(clk),         //system clock input
                     .i_instr(cip_instr),     //7-bit instruction input
                     .i_sj(s_j_data),        //64-bit sj input
                     .o_result(a_poplz_out));   //24-bit output

//Scalar Shift unit
scalar_shift sshift(.clk(clk), 
                    .i_instr(cip_instr),
                    .i_j(cip_j),
                    .i_k(cip_k),
                    .i_si(s_i_data), 
                    .i_sj(s_j_data), 
                    .i_ak(a_k_data), 
                    .o_result(s_shft_out));

s_const_gen sconst(.clk(clk),
                   .i_j(cip_j),
						 .i_ak(a_k_data),
						 .o_result(s_const_out));
//////////////////////////////////////////////////
//          Address Units                       //
//////////////////////////////////////////////////

//This block actually generates immediate values for both
//address and scalar instructions
imm_gen  igen(.clk(clk),
              .i_instr(cip_instr),
				  .i_cip_j(cip_j),
				  .i_cip_k(cip_k),
				  .i_lip(lip),
				  .i_sj(s_j_data),
			     .o_a_result(a_imm_out),
				  .o_s_result(s_imm_out));

//Address Addition unit
addr_add  aadd(.clk(clk),          //system clock input
               .i_instr(cip_instr),         //7-bit instruction input
               .i_aj(a_j_data),            //24-bit aj input
               .i_ak(a_k_data),            //24-bit ak input
               .o_result(a_add_out));       //24-bit output


//Address Multiply unit
fast_addr_mult amult(.clk(clk),         //system clock input
                .i_aj(a_j_data),           //24-bit aj input
                .i_ak(a_k_data),           //24-bit ak input
                .o_result(a_mul_out));      //24-bit output


/////////////////////////////////////////////////////////
//         Memory Controller Functional Unit           //
/////////////////////////////////////////////////////////

mem_fu mfu(.clk(clk),
              .rst(rst),
              .i_cip(cip),
				  .i_cip_vld(cip_vld),
				  .i_lip(lip),
				  .i_lip_vld(lip_vld),
				  .i_vector_length(vector_length),
				  .i_vstart(vfu_start[7]),
				  //interface to V regs
				  .i_v0_data(v_rd_data[63:0]),
				  .i_v1_data(v_rd_data[127:64]),
				  .i_v2_data(v_rd_data[191:128]),
				  .i_v3_data(v_rd_data[255:192]),
				  .i_v4_data(v_rd_data[319:256]),
				  .i_v5_data(v_rd_data[383:320]),
				  .i_v6_data(v_rd_data[447:384]),
				  .i_v7_data(v_rd_data[511:448]),
				  //interface to A rf
				  .i_a0_data(a_a0_data),
				  .i_ai_data(a_i_data),
				  .i_ak_data(a_k_data),
				  .i_ah_data(a_h_data),
				  .i_a_res_mask(a_res_mask),
				  //interface to s rf
				  .i_si_data(s_i_data),
				  .i_s_res_mask(s_res_mask),
				  //interface to B rf
				  .o_b_rd_addr(mem_b_rd_addr),
				  .i_b_rd_data(b_jk_data),
				  .o_b_wr_addr(mem_b_wr_addr),
				  .o_b_wr_en(mem_b_wr_en),
				  //interface to T rf
				  .o_t_rd_addr(mem_t_rd_addr),
				  .i_t_rd_data(t_jk_data),
				  .o_t_wr_addr(mem_t_wr_addr),
				  .o_t_wr_en(t_result_en),
				  //memory interface
				  .o_mem_busy(mem_ce),
				  .o_mem_data(data_from_mem_to_regs),
				  .o_mem_addr(o_mem_addr),
				  .i_mem_rd_data(i_data_from_mem),
				  .o_mem_wr_data(data_to_mem),
				  .o_mem_wr_en(mem_wr_en),
				  .o_mem_type(mem_type),
				  .o_mem_issue(mem_issue));
				  
				  

/////////////////////////////////////////////////////////
//         Misc. Registers, instruction decoding, etc. //
/////////////////////////////////////////////////////////


//Let's increment the real-time clock every cycle
//Unless it's a 0014x0 instruction, then set the RTC to (Sj)
//FIXME: This should only work in monitor mode!
always@(posedge clk)
   real_time_clock <= rst ? 64'b0 : ((cip[15:6]==16'o0014) && (cip_k==3'o0)) ? s_j_data : (real_time_clock + 64'b1);


//Control the vector mask register
always@(posedge clk)
   vector_mask <= rst ? 64'hFFFFFFFFFFFFFFFF :
                     (cip_instr==7'o003) ?  ((cip_j != 3'b0) ? s_j_data : 64'b0) :   //for some reason this is supposed to take 3-6 cyles (??)
                        vector_mask;
//Control the vector length register
always@(posedge clk)
   if(rst)
      vector_length <= 7'b1000000;
   else if(execution_mode==EXECUTE)
      begin
         vector_length <= (cip_instr==7'o002) ?  ((cip_k != 3'b0) ? a_k_data[6:0] : 7'b1) : vector_length;
      end
   else if((execution_mode==LOAD_EX_PKG) && (ex_pkg_cnt==4'b0011))
         vector_length <= i_word_nxt[39:33];




/*
   vector_length <= rst ? 7'b1000000 :
                     (execution_mode==EXECUTE) ? 
                     (cip_instr==7'o002) ?  ((cip_k != 3'b0) ? a_k_data[6:0] : 7'b1) :   //for some reason this is supposed to take 3-6 cyles (??)
                        vector_length;
*/


brancher brnch(.clk(clk),
                .i_cip(cip),
					 .i_cip_vld(cip_vld),
					 .i_lip(lip),
					 .i_lip_vld(lip_vld),
					 .i_a0_neg(a0_neg),
					 .i_a0_pos(a0_pos),
					 .i_a0_zero(a0_zero),
					 .i_a0_nzero(a0_nzero),
					 .i_a0_busy(a0_busy),
					 .i_s0_neg(s0_neg),
					 .i_s0_pos(s0_pos),
					 .i_s0_zero(s0_zero),
					 .i_s0_nzero(s0_nzero),
					 .i_s0_busy(s0_busy),
					 .i_bjk(b_jk_data),
					 .o_branch_type(branch_type),
					 .o_branch_issue(branch_issue),
					 .o_take_branch(take_branch),
					 .o_rtn_jump(rtn_jump),
					 .o_nxt_p(branch_dest));
					 
					 
//Program Counter
//If it's not a branch, increment when we issue the current instruction parcel
//If it *is* a branch, jump to the appropriate destination
always@(posedge clk)
   if(rst)
      p_addr <= 24'b0;
   else if (execution_mode == EXECUTE)
	   p_addr <= (issue_vld && i_nip_vld) ? (take_branch ? branch_dest : (p_addr + 1)) : p_addr;
	else if ((execution_mode == LOAD_EX_PKG) && (ex_pkg_cnt==4'b0000))
	   p_addr <= i_word_nxt[47:24];



endmodule
