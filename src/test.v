`define state_a 8'h61
`define state_b 8'h62
`define state_c 8'h63
`define state_d 8'h64
`define state_e 8'h65
`define state_f 8'h66
`define state_g 8'h67
`define state_h 8'h68
`define state_i 8'h69
`define state_j 8'h6a
`define state_k 8'h6b
`define state_l 8'h6c
`define state_m 8'h6d
`define state_n 8'h6e
`define state_o 8'h6f
`define state_p 8'h70
`define state_q 8'h71
`define state_r 8'h72
`define state_s 8'h73
`define state_t 8'h74
`define state_u 8'h75
`define state_v 8'h76
`define state_w 8'h77
`define state_x 8'h78
`define state_y 8'h79
`define state_z 8'h7a
`define state_0 8'h30
`define state_1 8'h31
`define state_2 8'h32
`define state_3 8'h33
`define state_4 8'h34
`define state_5 8'h35
`define state_6 8'h36
`define state_7 8'h37
`define state_8 8'h38
`define state_9 8'h39

module clk_1s(input clk,output reg clk1);
reg [31:0] cnt;
initial begin  cnt<='d0;clk1<=0; end
always @(posedge clk) 
begin 
if(cnt=='d24999999) begin clk1=~clk1;cnt='d0; end
else cnt<=cnt+5'd1;
end
endmodule

module clk_1ms(input clk,output reg clk2);
reg [31:0] cnt;
initial begin  cnt<='d0;clk2<=0; end
always @(posedge clk)
begin
if(cnt=='d24999) begin clk2=~clk2;cnt='d0; end
else cnt=cnt+5'd1;
end
endmodule

module scan(input clk_1ms,input key,output reg[1:0] out);
reg [8:0] cnt1;
reg [8:0] cnt0;
reg [8:0] cnt;
reg EN0,EN1;
initial begin out<=2'b00;cnt1<='b000000000;cnt0<='b000000000;end
always @(posedge clk_1ms)
begin
if(key) 
begin
    cnt0=0;
    if(cnt1<=500) begin cnt1=cnt1+1; end 
    if(cnt0<1000&&EN0) begin out=2'b00; end//00 short 0
    if(cnt0>1000&&EN0) begin out=2'b01; end//01 long 0
end
if(!key)
begin
    cnt1=0;
    if (cnt0<=1001) begin cnt0=cnt0+1; end
    if(cnt1<500&&EN1) begin out=2'b10; end//10 short 1
    if(cnt1>500&&EN1) begin out=2'b11; end//11 long 1
end
end
always@(cnt0) begin EN0=1; end
always@(negedge clk_1ms) begin if(EN0==1) begin EN0=0; end end
always@(cnt0) begin EN1=1; end
always@(negedge clk_1ms) begin if(EN1==1) begin EN1=0; end end
endmodule

module dynamic_display(input[3:0] IN1,IN2,IN3,IN4,IN5,IN6,
input  clk,
output reg [7:0]  DISPLAYOUT,
output reg [5:0]DIG);
reg [7:0] D[15:0];
reg [2:0]cnt;
initial begin
    D[0]='h3f;
    D[1]='h06; 
    D[2]='h5b;
    D[3]='h4f;
    D[4]='h66;   
    D[5]='h6c;    
    D[6]='h9b;  
    D[7]='h07;
    D[8]='h7f;  
    D[9]='h6f; 
    D[10]='h77;
    D[11]='h7c;
    D[12]='h39;
    D[13]='h5e;
    D[14]='h79;  
    D[15]='h71;//0xc0,0xf9,0xa4,0xb0,0x99,0x92,0x82,0xf8,0x80,0x90,0x88,0x83,0xc6,0xa1,0x86,0x8e
    DIG=6'b111111;
    cnt=3'b000;
    end
    always @(posedge clk) begin cnt<=cnt+1; end
    always@(posedge clk)
    begin
        case(cnt)
            3'b000:begin DISPLAYOUT=D[IN1]; DIG=6'b111110; end
            3'b001:begin DISPLAYOUT=D[IN2]; DIG=6'b111101; end
            3'b010:begin DISPLAYOUT=D[IN3]; DIG=6'b111011; end
            3'b011:begin DISPLAYOUT=D[IN4]; DIG=6'b110111; end
            3'b100:begin DISPLAYOUT=D[IN5]; DIG=6'b101111; end
            3'b101:begin DISPLAYOUT=D[IN6]; DIG=6'b011111; end
        endcase
    end
endmodule

module status(
    input [1:0]out,
    output reg [9:0]state,
    output reg change
);
reg [2:0] cnt;
initial begin state<=0; change<=0; cnt<=0; end
always @(out)
begin

    case(out)
    2'b00:begin cnt=cnt+1; end
    2'b01:begin change=~change; cnt=0; state<=0; end
    2'b10:begin state[9-cnt-:2]<=10; end
    2'b11:begin state[9-cnt-:2]<=11; end
    endcase
end
endmodule

module trans(input change,input[7:0]N,output reg [7:0]N12,N34,N56);
initial begin N12<=0; N34<=0;N56=0; end
always @(change)
begin N56<=N34; N34<=N12; end
always @(N)
begin N12<=N; end
endmodule

module decode(input [9:0] state,output reg [7:0]N);
always@(*)
begin
    case(state)
    'b1111111111: begin N<=`state_0; end
    'b1011111111: begin N<=`state_1; end
    'b1010111111: begin N<=`state_2; end
    'b1010101111: begin N<=`state_3; end
    'b1010101011: begin N<=`state_4; end
    'b1010101010: begin N<=`state_5; end
    'b1110101010: begin N<=`state_6; end
    'b1111101010: begin N<=`state_7; end
    'b1111111010: begin N<=`state_8; end
    'b1111111110: begin N<=`state_9; end
    endcase
end
endmodule

module main (input clk,key,output[5:0] DIG,output[7:0]DISPLAYOUT);
wire clk_1ms,change;
wire[1:0] out;
wire[9:0] state;
wire[7:0] N,N12,N34,N56;
clk_1ms div(clk,clk_1ms);
scan scan(clk_1ms,key,out);
status status(out,state,change);
decode decode(state,N);
trans N2N6(change,N,N12,N34,N56);
dynamic_display display(N12[3:0],N12[7:4],N34[3:0],N34[7:4],N56[3:0],N56[7:4],clk,DIG,DISPLAYOUT);
endmodule
