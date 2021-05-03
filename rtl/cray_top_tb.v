module cray_top_tb;

reg clk;
reg rst;
wire  [63:0] s_out;
wire  [23:0] a_out;
wire [63:0]  o_result;

wire [21:0] mem_addr;
wire [63:0] mem_wr_data;
wire [63:0] mem_rd_data;
wire        mem_wr_en;
reg  [63:0] cur_instr;

reg  [63:0] data [127:0];

localparam instr0 = 16'o072300,      //Transmit (RTC) to S3
           instr1 = 16'o077230,      //Transmit S3 to V2 element A0
			  instr2 = 16'o155123,      //Integer sum: V1 = V2 + V3
			  instr3 = 16'o022106,      //transmit 06 to register A1
			  instr4 = 16'o034100,      //transfer (A1) words from mem, start at addr A0, to B regs starting at jk=00
			  instr5 = 16'o035100,      //transfer (A1) words from B regs starting at jk=00 to mem, starting at addr A0
			  instr6 = 16'o036100,      //transfer (A1) words from mem, start at addr A0, to T regs starting at jk=00
			  instr7 = 16'o037100,      //transfer (A1) words from T regs starting at jk=00 to mem, starting at addr A0
			  instr8 = 16'o100000,      //read from ((Ah) + jkm) to Ai
			  instr9 = 16'o000000,      //(continued)
			  instr10= 16'o110000,      // store (Ai) to ((Ah) + jkm)
           instr11= 16'o000000,      // (continued)
			  instr12= 16'o120000,      // read from ((Ah) + jkm) to Si
			  instr13= 16'o000000,      //(continued)
			  instr14= 16'o130000,      // store (Si) to ((Ah) + jkm)
			  instr15= 16'o000000,      // (continued)
			  instr16= 16'o022000,      //transmit 00 to register A0
			  instr17= 16'o176000,      // transmit (VL) words from memory to Vi elements starting at addr (A0) and incrementing by (Ak)
		     instr18= 16'o177000,      //transmit (VL) words from Vj elements to memory starting at addr (A0) and incrementing by (Ak)
      	  instr19= 16'o006000;      //Branch to IJKM=0x00000000 (Instr0)

cray_top dut(.clk(clk),
             .rst(rst),
				 .o_s_out(s_out),
				 .o_a_out(a_out),
				 .o_mem_addr(mem_addr),
				 .o_mem_wr_data(mem_wr_data),
				 .i_mem_rd_data(mem_rd_data),
				 .o_mem_wr_en(mem_wr_en));
				 

// For now, bottom kilobyte of code is instructions
// upper kilobyte of code is just RAM

assign mem_rd_data = mem_wr_en ? 64'b0 : mem_addr[8] ? data[mem_addr[7:0]] : cur_instr;

always@(posedge clk)
   if(mem_wr_en)
	   data[mem_addr[7:0]] <= mem_wr_data;
		

always@*
   case(mem_addr[3:0])
	   4'b0000:cur_instr={instr3,instr2,instr1,instr0};
		4'b0001:cur_instr={instr7,instr6,instr5,instr4};
		4'b0010:cur_instr={instr11,instr10,instr9,instr8};
		4'b0011:cur_instr={instr15,instr14,instr13,instr12};
		4'b0100:cur_instr={instr19,instr18,instr17,instr16};
		4'b0101:cur_instr=64'b0;
		4'b0110:cur_instr=64'b0;
		4'b0111:cur_instr=64'b0;
		default:cur_instr=64'b0;
	endcase

initial begin
    $dumpfile("cray_top_tb.dump");
    $dumpvars(0,cray_top_tb);
    clk <= 1'b0;
    rst <= 1'b1;
	 #55
    rst <= 1'b0;       //7 in decimal
    #7500
    $finish();
end


always begin
    #10 clk <= ~clk;
end






endmodule
