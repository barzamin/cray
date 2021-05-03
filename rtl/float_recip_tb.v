module float_recip_tb;

reg clk;
reg [63:0] i_sj;
wire [63:0] o_result;


float_recip dut(clk,i_sj,o_result);

initial begin
    $dumpfile("float_recip_tb.dump");
    $dumpvars(0,float_recip_tb);
    clk <= 1'b0;
    i_sj <= 64'b0;
	 #35
    i_sj <= 64'h4007C00000000000;       //7 in decimal
    #20
	 i_sj <= 64'b0;
    #1200                               //result should be equal to 100

    $finish();
end


always begin
    #10 clk <= ~clk;
end






endmodule
