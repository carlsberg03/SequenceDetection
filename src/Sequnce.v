`timescale 1ns/10ps

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
//模块的运行逻辑是检测长0（01），短0（00），长1（11），短1（10），然后做串并转换、译码到数码管实现摩斯电码检测。
//六位数码管支持最多三个ASCII码的显示，同样使用移位寄存器，每当检测到长0的时候逻辑左移。
//由于抖动影响太大，选取了100ms消抖。因此·的表示应在100ms-1s之间，-的表示应大于1s
//连续·-的输入间隔应在2s内完成，相应的，两个不同莫斯码的输入间隔应大于2s
//错误的、过快的、过慢的输入会引起不可知的时序错误



//移位寄存按键消抖
module remove_joggle(key_in,clk,key_out);
input key_in,clk;
output reg key_out;
reg q0,q1,q2,q3,q4,q5,q6,q7,q8,q9;
initial begin q0<=1;q1<=1;q2<=1;q3<=1;q4<=1;q5<=1;q6<=1;q7<=1;q8<=1;q9<=1; key_out<=0;end
always @(posedge clk)
begin 
 q9 <= q8;
 q8 <= q7;
 q7 <= q6;
 q6 <= q5;
 q5 <= q4;
 q4 <= q3;
 q3 <= q2;
 q2 <= q1;
 q1 <= q0;
 q0 <= key_in;
end
always@(*)
begin
if(q0&q1&q2&q3&q4&q5&q6&q7&q8&q9&key_out) begin key_out = 0; end
if(~(q0|q1|q2|q3|q4|q5|q6|q7|q8|q9)&~key_out) begin key_out <= 1; end
end
endmodule

//50Mhz->1KHz
module clk_1ms(input clk,output reg clk2);
reg [31:0] cnt;
initial begin  cnt=0;clk2=0; end
always @(posedge clk)
begin
if(cnt=='d24999) begin clk2=~clk2;cnt=0; end
else cnt=cnt+1;
end
endmodule

//50MHz->100Hz
module clk_10ms(input clk,output reg clk2);
reg [31:0] cnt;
initial begin  cnt=0;clk2=0; end
always @(posedge clk)
begin
if(cnt=='d249999) begin clk2=~clk2;cnt=0; end
else cnt=cnt+1;
end
endmodule

//计数确定输出长短，00为短0，01为长0，10为短1，11为长1
module scan(input clk_1ms,input key,output reg[1:0] out);
reg[15:0]cnt1,cnt0;
initial begin out<=2'b01;cnt1<=0;cnt0<=0;end
always @(posedge clk_1ms)
begin
if(key) 
begin
    if(cnt0<2000&&cnt0!=0) begin out<=2'b00;cnt0<=0; end//00 short 0
    if(cnt0>=2000) begin out<=2'b01; cnt0<=0; end//01 long 0
    if(cnt1<=2000) begin cnt1=cnt1+1; end 
end
if(!key)
begin
    if(cnt1<1000&&cnt1!=0) begin out<=2'b10;cnt1<=0; end//10 short 1
    if(cnt1>=1000) begin out<=2'b11; cnt1<=0; end//11 long 1
    if(cnt0<=3000) begin cnt0=cnt0+1; end 
end
end
endmodule

//六位共阴极数码管的动态显示，数码管输出为IN6->IN1对应的值。例如，当IN1为0111时，第一个数码管显示7
module dynamic_display(input[3:0] IN1,IN2,IN3,IN4,IN5,IN6,input  clk,output reg [7:0]  DISPLAYOUT,output reg [5:0]DIG);
reg [7:0] D[15:0];
reg [2:0]cnt;
initial begin
    D[0]='h3f;
    D[1]='h06; 
    D[2]='h5b;
    D[3]='h4f;
    D[4]='h66;   
    D[5]='h6d;    
    D[6]='h9b;  
    D[7]='h07;
    D[8]='h7f;  
    D[9]='h6f; 
    D[10]='h77;
    D[11]='h7c;
    D[12]='h39;
    D[13]='h5e;
    D[14]='h79;  
    D[15]='h71;
    DIG=6'b000000;
    cnt=3'b000;
    DISPLAYOUT<=0;
    end
    always @(posedge clk) begin 
    if(cnt<6)cnt=cnt+1;
    if(cnt==6)cnt=0; 
    end
    always@(posedge clk)
    begin
        case(cnt)
            3'b000:begin DISPLAYOUT<=D[IN1]; DIG<=6'b111110; end
            3'b001:begin DISPLAYOUT<=D[IN2]; DIG<=6'b111101; end
            3'b010:begin DISPLAYOUT<=D[IN3]; DIG<=6'b111011; end
            3'b011:begin DISPLAYOUT<=D[IN4]; DIG<=6'b110111; end
            3'b100:begin DISPLAYOUT<=D[IN5]; DIG<=6'b101111; end
            3'b101:begin DISPLAYOUT<=D[IN6]; DIG<=6'b011111; end
        endcase
    end
endmodule


//串并转换，将scan模块中串行输出的out转化成N
//当出现长0即一个莫斯码的结尾，change变为1并在下一个时钟沿变0
module status(input clk,input [1:0]out,output reg [9:0]state,output reg change);
initial begin state<=0; change<=0; end
reg EN;
initial begin EN<=0; end
always@(posedge clk)
begin
    case(out)
    2'b00:begin EN<=1; end
    2'b01:begin change<=1;state=0;EN<=1; end
    2'b10:begin if(EN) begin EN<=0;state[9:0]<={state[7:0],2'b10}; change<=0;end end
    2'b11:begin if(EN) begin EN<=0;state[9:0]={state[7:0],2'b11};  change<=0;end end
    endcase
end
endmodule


//数码管移位显示模块，每当输入一个新的莫斯码时，已有的莫斯码左移两位
module trans(input clk,input change,input[7:0]N,output reg [7:0]N12,N34,N56);
initial begin N12<=0; N34<=0;N56=0; end
reg EN;
initial begin EN=0; end
always @(posedge clk)
begin N12<=N; end
always @(posedge change)
begin
N56<=N34;N34<=N12;
end
endmodule

//解码模块，将对应的莫斯码转化成ASCII码
module decode(input clk,input [9:0] state,output reg [7:0]N);
initial begin N<=0; end
always@(posedge clk)
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
//目前仅有数字莫斯码转化，若要实现字母转换在此处添加
//例如A的莫斯码为.-，即’b 00 00 00 10 11 ，ascii码’h61，则添加代码为
//  'b0000001011: begin N<='h61; end
    default: begin N<=0 ;end
    endcase
end
endmodule

//主模块，将上述模块连接
module main (input clk,key,output[5:0] DIG,output[7:0]DISPLAYOUT,output test,output change,output [1:0] out,output [7:0]cnt);
wire clk2,clk3;
wire[9:0] state;
wire[7:0] N,N12,N34,N56;
wire key_out;
assign cnt=state[7:0];
clk_1ms div21ms(clk,clk2);
clk_10ms div210ms(clk,clk3);
remove_joggle remove(key,clk3,key_out);
assign test=key_out;
scan key_pressed(clk2,key_out,out);
status status(clk,out,state,change);
decode state_to_digital_display(clk2,state,N);
trans static_to_dynamic(clk,change,N,N12,N34,N56);
dynamic_display display(N12[3:0],N12[7:4],N34[3:0],N34[7:4],N56[3:0],N56[7:4],clk2,DISPLAYOUT,DIG);
endmodule







//下面注释掉的是三个仿真激励测试
/*
module testbench_main(output[5:0] DIG,output[7:0]DISPLAYOUT,output test,output change);
reg clk,key;
wire[7:0] cnt;
wire[1:0] out;
initial begin clk<=0; key<=1; #100000000 key<=0; #200000000 key<=1; #200000000 key<=0; #200000000 key<=1; #200000000 key<=0; #200000000 key<=1 ;#200000000 key<=0;#200000000 key<=1 ;#200000000 key<=0; #200000000 key<=1;#200000000 key<=0; #200000000 key<=1;end
always #10 clk=~clk;
wire clk2,clk3;
wire[9:0] state;
wire[7:0] N,N12,N34,N56;
wire key_out;
assign cnt=state[7:0];
clk_1ms div21ms(clk,clk2);
clk_10ms div210ms(clk,clk3);
remove_joggle remove(key,clk3,key_out);
assign test=key_out;
scan key_pressed(clk2,key_out,out);
status status(clk,out,state,change);
decode state_to_digital_display(clk2,state,N);
trans static_to_dynamic(clk,change,N,N12,N34,N56);
dynamic_display display(N12[3:0],N12[7:4],N34[3:0],N34[7:4],N56[3:0],N56[7:4],clk2,DISPLAYOUT,DIG);
endmodule
*/
/*
module testbench_remove_joggle();
reg clk,key;
wire keyout;
always #10 clk=~clk;
initial begin key=1;clk=0; #1000 key=10; #1000 key=1;end
remove_joggle remove(key,clk,keyout);
endmodule
*/
/*
module testbench_status();
reg  [1:0] out;
wire[9:0] state;
wire change;
initial begin out<='b01; #100 out<='b10; #100 out<='b00; #100 out<='b10; end
status status(out,state,change);
endmodule
*/

