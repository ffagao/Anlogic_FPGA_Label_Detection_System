`timescale 1ns/1ps
module tb_v33_uart;
reg clk=0;always #10 clk=~clk;
reg rst=0,rx=1;reg [3:0] switches=0;
wire [3:0] mode;wire command_valid;wire [15:0] command;
uart_switch_control #(.DEBOUNCE_CYCLES(16)) receiver(clk,rst,rx,switches,mode,command_valid,command);
integer commands=0;reg [15:0] last_command;
always @(posedge clk) if(command_valid) begin commands=commands+1;last_command=command;end
task send(input [7:0] value);
 integer j;
 begin rx=0;#8680;for(j=0;j<8;j=j+1)begin rx=value[j];#8680;end rx=1;#8680;end
endtask
task task_frame(input [7:0] op,input [7:0] value);
 begin send(8'ha5);send(op);send(value);send(8'ha5^op^value);#1000;end
endtask
wire mb_ready,mb_valid;wire [15:0] mb_data;
reg dst_clk=0;always #6.667 dst_clk=~dst_clk;
target_control_mailbox mailbox(clk,rst,command_valid,command,mb_ready,dst_clk,rst,mb_valid,mb_data);
integer delivered=0;reg [15:0] delivered_data;
always @(posedge dst_clk) if(mb_valid) begin delivered=delivered+1;delivered_data=mb_data;end
reg update=0,query=0;reg [3:0] report_mode=0;reg [39:0] report_data=0;wire tx;
target_uart_report #(.PERIOD_CYCLES(1000000)) reporter(clk,rst,update,query,report_mode,report_data,tx);
string line="",last_line="";integer lines=0,bytes=0,j;reg [7:0] value;
initial forever begin
 @(negedge tx);#13020;value=0;
 for(j=0;j<8;j=j+1) begin value[j]=tx;#8680;end
 if(tx!==1) $fatal(1,"UART TX stop bit");
 bytes=bytes+1;
 if(value==10) begin last_line=line;line="";lines=lines+1;end
 else line={line,value};
 #2170;
end
task publish(input [3:0] m,input bit good,input [2:0] colour,input [1:0] shape);
 begin
  @(negedge clk);report_data={m,good,colour,shape,11'd960,10'd240,1'b0,4'd3,4'd3};update=1;
  @(negedge clk);update=0;repeat(5)@(negedge clk);
 end
endtask
integer old_count,i;
initial begin
 repeat(5)@(negedge clk);rst=1;
 send(2);#1000;if(mode!=2) $fatal(1,"legacy raw SW");
 task_frame(1,5);if(mode!=2 || commands!=1 || last_command!=16'h0105 || delivered!=1 || delivered_data!=16'h0105) $fatal(1,"colour task/mailbox");
 task_frame(2,3);task_frame(3,1);task_frame(4,0);task_frame(5,1);
 if(commands!=5 || mode!=2) $fatal(1,"framed payload accidentally changed SW");
 send(8'ha5);send(1);send(0);send(0);#1000;
 if(commands!=5 || mode!=2) $fatal(1,"bad checksum accepted");
 task_frame(2,0);task_frame(1,6);task_frame(8'hff,0);
 if(commands!=5) $fatal(1,"invalid task/value");
 send(8'ha5);send(1);#21000000;send(4);#1000;if(mode!=4) $fatal(1,"parser timeout recovery");
 for(i=0;i<16;i=i+1) begin send(i);#1000;if(mode!=i) $fatal(1,"legacy mode %d",i);end
 // No telemetry in colour selection/learning mode or other unused modes.
 report_mode=1;publish(1,1,5,1);#1000000;if(tx!==1 || bytes!=0) $fatal(1,"0001 must stay silent");
 report_mode=4;repeat(4)@(negedge clk);publish(4,1,5,3);publish(4,1,5,3);
 wait(lines>=2);#100;
 if(last_line.len()!=63 || last_line.substr(0,3)!="SW:4" || last_line.substr(13,25)!="COLOR:CUSTOM " ||
    last_line.substr(27,40)!="SHAPE:TRIANGLE" || last_line.substr(42,47)!="X:03C0" || last_line.substr(49,54)!="Y:00F0")
  $fatal(1,"telemetry snapshot/format [%s]",last_line);
 old_count=lines;publish(4,0,5,3);publish(4,0,5,3);wait(lines>old_count);#100;
 if(last_line.substr(5,11)!="VALID:0" || last_line.substr(19,22)!="NONE" || last_line.substr(33,36)!="NONE")
  $fatal(1,"invalid target must not repeat selected colour/shape [%s]",last_line);
 report_mode=0;#10000;old_count=bytes;#1000000;
 if(tx!==1 || bytes!=old_count) $fatal(1,"mode exit telemetry");
 report_mode=2;repeat(4)@(negedge clk);publish(2,1,0,1);publish(2,1,0,1);old_count=lines;wait(lines>old_count+1);#100;
 if(last_line.substr(0,3)!="SW:2" || last_line.substr(19,22)!="BLUE" || last_line.substr(33,36)!="RECT") $fatal(1,"blue report");
 report_mode=6;#10000;old_count=bytes;#1000000;if(bytes!=old_count) $fatal(1,"60FPS must stay silent");
 $display("PASS tb_v33_uart: real 115200 framed/raw commands, checksum/value validation, timeout, async mailbox, TX byte timing, actual names/coordinates, NONE, 0010/0100-only telemetry");$finish;
end
initial begin #150000000;$fatal(1,"UART timeout %s",last_line);end
endmodule
