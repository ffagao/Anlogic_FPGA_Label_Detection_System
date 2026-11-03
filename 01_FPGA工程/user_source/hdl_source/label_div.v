// Shared restoring divider: fixed 32-clock latency, no pixel-path division.
module label_div(input wire clk,rst_n,start,abort,input wire [31:0] n,
                 input wire [15:0] d,output reg done,output reg [31:0] q);
    reg busy; reg [5:0] count; reg [31:0] bits;
    reg [15:0] divisor,rem;
    wire [16:0] trial={rem,bits[31]};
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin busy<=0;done<=0;q<=0;bits<=0;rem<=0;divisor<=1;count<=0;end
        else begin
            done<=0;
            if(abort) busy<=0;
            else if(start && !busy) begin
                busy<=1;count<=0;bits<=n;divisor<=d==0?16'd1:d;rem<=0;q<=0;
            end else if(busy) begin
                bits<=bits<<1;
                if(trial>={1'b0,divisor}) begin rem<=trial-divisor;q<={q[30:0],1'b1};end
                else begin rem<=trial;q<={q[30:0],1'b0};end
                if(count==31) begin busy<=0;done<=1;end else count<=count+1'b1;
            end
        end
    end
endmodule
