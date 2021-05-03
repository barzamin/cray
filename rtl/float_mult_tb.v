module float_mult_tb;

logic clk;
logic [63:0] i_sj;
logic [63:0] i_sk;
logic [63:0] o_result;
logic [6:0] i_instr;

float_mult dut(clk, i_instr, i_sj, i_sk, o_result);




initial begin
    $dumpfile("float_mult_tb.dump");
    $dumpvars(0,float_mult_tb);
    clk <= 1'b0;
    i_sj <= 64'h4004A00000000000;       //10 in decimal
    i_sk <= 64'h4004A00000000000;       //10 in decimal
    i_instr <= 7'b0110110; 
    #600                                //result should be equal to 100

    $finish();
end


always begin
    #10 clk <= ~clk;
end


endmodule


