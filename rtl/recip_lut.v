//******************************************
//       Floating RA Look-Up Table 
//******************************************
//
//This file is the look-up table for the initial guess
// of the floating point reciprocol unit
// (because it uses newton-raphson)
//
//The input is the first 7 bits after the MSB of the input mantissa
//the output is the 4 bits after the MSB of the result mantissa

module recip_lut(n, mantissa);

input  wire [6:0] n;
output reg [3:0] mantissa;

always@*
begin
case(n[6:0])
7'b0000000: mantissa = 4'b0000;
7'b0000001: mantissa = 4'b1111;
7'b0000010: mantissa = 4'b1111;
7'b0000011: mantissa = 4'b1111;
7'b0000100: mantissa = 4'b1111;
7'b0000101: mantissa = 4'b1110;
7'b0000110: mantissa = 4'b1110;
7'b0000111: mantissa = 4'b1110;
7'b0001000: mantissa = 4'b1110;
7'b0001001: mantissa = 4'b1101;
7'b0001010: mantissa = 4'b1101;
7'b0001011: mantissa = 4'b1101;
7'b0001100: mantissa = 4'b1101;
7'b0001101: mantissa = 4'b1101;
7'b0001110: mantissa = 4'b1100;
7'b0001111: mantissa = 4'b1100;
7'b0010000: mantissa = 4'b1100;
7'b0010001: mantissa = 4'b1100;
7'b0010010: mantissa = 4'b1100;
7'b0010011: mantissa = 4'b1011;
7'b0010100: mantissa = 4'b1011;
7'b0010101: mantissa = 4'b1011;
7'b0010110: mantissa = 4'b1011;
7'b0010111: mantissa = 4'b1011;
7'b0011000: mantissa = 4'b1010;
7'b0011001: mantissa = 4'b1010;
7'b0011010: mantissa = 4'b1010;
7'b0011011: mantissa = 4'b1010;
7'b0011100: mantissa = 4'b1010;
7'b0011101: mantissa = 4'b1010;
7'b0011110: mantissa = 4'b1001;
7'b0011111: mantissa = 4'b1001;
7'b0100000: mantissa = 4'b1001;
7'b0100001: mantissa = 4'b1001;
7'b0100010: mantissa = 4'b1001;
7'b0100011: mantissa = 4'b1001;
7'b0100100: mantissa = 4'b1000;
7'b0100101: mantissa = 4'b1000;
7'b0100110: mantissa = 4'b1000;
7'b0100111: mantissa = 4'b1000;
7'b0101000: mantissa = 4'b1000;
7'b0101001: mantissa = 4'b1000;
7'b0101010: mantissa = 4'b1000;
7'b0101011: mantissa = 4'b0111;
7'b0101100: mantissa = 4'b0111;
7'b0101101: mantissa = 4'b0111;
7'b0101110: mantissa = 4'b0111;
7'b0101111: mantissa = 4'b0111;
7'b0110000: mantissa = 4'b0111;
7'b0110001: mantissa = 4'b0111;
7'b0110010: mantissa = 4'b0111;
7'b0110011: mantissa = 4'b0110;
7'b0110100: mantissa = 4'b0110;
7'b0110101: mantissa = 4'b0110;
7'b0110110: mantissa = 4'b0110;
7'b0110111: mantissa = 4'b0110;
7'b0111000: mantissa = 4'b0110;
7'b0111001: mantissa = 4'b0110;
7'b0111010: mantissa = 4'b0110;
7'b0111011: mantissa = 4'b0101;
7'b0111100: mantissa = 4'b0101;
7'b0111101: mantissa = 4'b0101;
7'b0111110: mantissa = 4'b0101;
7'b0111111: mantissa = 4'b0101;
7'b1000000: mantissa = 4'b0101;
7'b1000001: mantissa = 4'b0101;
7'b1000010: mantissa = 4'b0101;
7'b1000011: mantissa = 4'b0101;
7'b1000100: mantissa = 4'b0100;
7'b1000101: mantissa = 4'b0100;
7'b1000110: mantissa = 4'b0100;
7'b1000111: mantissa = 4'b0100;
7'b1001000: mantissa = 4'b0100;
7'b1001001: mantissa = 4'b0100;
7'b1001010: mantissa = 4'b0100;
7'b1001011: mantissa = 4'b0100;
7'b1001100: mantissa = 4'b0100;
7'b1001101: mantissa = 4'b0011;
7'b1001110: mantissa = 4'b0011;
7'b1001111: mantissa = 4'b0011;
7'b1010000: mantissa = 4'b0011;
7'b1010001: mantissa = 4'b0011;
7'b1010010: mantissa = 4'b0011;
7'b1010011: mantissa = 4'b0011;
7'b1010100: mantissa = 4'b0011;
7'b1010101: mantissa = 4'b0011;
7'b1010110: mantissa = 4'b0011;
7'b1010111: mantissa = 4'b0011;
7'b1011000: mantissa = 4'b0010;
7'b1011001: mantissa = 4'b0010;
7'b1011010: mantissa = 4'b0010;
7'b1011011: mantissa = 4'b0010;
7'b1011100: mantissa = 4'b0010;
7'b1011101: mantissa = 4'b0010;
7'b1011110: mantissa = 4'b0010;
7'b1011111: mantissa = 4'b0010;
7'b1100000: mantissa = 4'b0010;
7'b1100001: mantissa = 4'b0010;
7'b1100010: mantissa = 4'b0010;
7'b1100011: mantissa = 4'b0010;
7'b1100100: mantissa = 4'b0001;
7'b1100101: mantissa = 4'b0001;
7'b1100110: mantissa = 4'b0001;
7'b1100111: mantissa = 4'b0001;
7'b1101000: mantissa = 4'b0001;
7'b1101001: mantissa = 4'b0001;
7'b1101010: mantissa = 4'b0001;
7'b1101011: mantissa = 4'b0001;
7'b1101100: mantissa = 4'b0001;
7'b1101101: mantissa = 4'b0001;
7'b1101110: mantissa = 4'b0001;
7'b1101111: mantissa = 4'b0001;
7'b1110000: mantissa = 4'b0001;
7'b1110001: mantissa = 4'b0000;
7'b1110010: mantissa = 4'b0000;
7'b1110011: mantissa = 4'b0000;
7'b1110100: mantissa = 4'b0000;
7'b1110101: mantissa = 4'b0000;
7'b1110110: mantissa = 4'b0000;
7'b1110111: mantissa = 4'b0000;
7'b1111000: mantissa = 4'b0000;
7'b1111001: mantissa = 4'b0000;
7'b1111010: mantissa = 4'b0000;
7'b1111011: mantissa = 4'b0000;
7'b1111100: mantissa = 4'b0000;
7'b1111101: mantissa = 4'b0000;
7'b1111110: mantissa = 4'b0000;
7'b1111111: mantissa = 4'b0000;
endcase
end




endmodule
