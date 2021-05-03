module cray_sys_top_tb;

reg clk;
reg rst;
reg clk_rst;
wire tx_out;
wire rx_in;
wire led;

reg rd_clr;          
reg tx_start;  
reg [63:0] mem_wr_data;                                                
wire       tx_busy;            
wire       rx_data_rdy;   
wire [63:0] rx_data;	
	

cray_sys_top dut(.clk(clk),
                 .rst(rst),
					  .clk_rst(clk_rst),
					  .tx_out(tx_out),
					  .rx_in(rx_in),
					  .o_led(led));
   
	
uart64 tb_serport(.clk(clk),
             .rst(rst),
             .enable_read(rd_clr),          
             .enable_write(tx_start),  
             .data_in(mem_wr_data),             
             .data_out(rx_data),              
             .uart_read(tx_out),             
             .uart_write(rx_in),           
             .busy_write(tx_busy),            
             .data_avail(rx_data_rdy));   	
	
	
	initial begin
    $dumpfile("cray_sys_top_tb.dump");
    $dumpvars(0,cray_sys_top_tb);
    clk <= 1'b0;
    rst <= 1'b1;
	 clk_rst <= 1'b1;
	 rd_clr  <= 1'b0;          
    tx_start <= 1'b0;  
    mem_wr_data <= 64'b0;                                                
	 #50
	 clk_rst <= 1'b0;
	 #2500
    rst <= 1'b0;       //7 in decimal
    #100000
    $finish();
end


always begin
    #10 clk <= ~clk;
end
endmodule
