// Three consecutive fresh observations, fused before relative coordinates are
// calculated. One shared median datapath avoids parallel multiplier resources.
module label_observation_fusion_reference(
    input wire clk,rst_n,enable,sample,valid,input wire [3:0] reason,
    input wire [11:0] bx,by,bw,bh,lx,ly,lw,lh,
    input wire [8:0] ba,la,input wire bsquare,lsquare,
    output reg busy,O_sample,O_valid,output reg [3:0] O_reason,
    output wire [11:0] O_bx,O_by,O_bw,O_bh,O_lx,O_ly,O_lw,O_lh,
    output wire [8:0] O_ba,O_la,output reg O_bsquare,O_lsquare);
    reg [1:0] count;
    reg [119:0] history0,history1,history2,fused;
    reg [8:0] anchor_ba,anchor_la;
    reg anchor_bs,anchor_ls,second_bs,second_ls;
    reg [3:0] item;
    wire [119:0] first_record={24'd0,lh,lw,ly,lx,bh,bw,by,bx};
    wire signed [10:0] db,dl;
    reg signed [11:0] relative_change;
    function signed [10:0] angle_delta;
        input [8:0] a,b;input square;
        reg signed [10:0] d;
        begin
            d=$signed({1'b0,a})-$signed({1'b0,b});
            if(d>180) d=d-360;else if(d< -180) d=d+360;
            if(square) begin if(d>90) d=d-180;else if(d< -90) d=d+180;end
            angle_delta=d;
        end
    endfunction
    assign db=angle_delta(ba,anchor_ba,anchor_bs || bsquare);
    assign dl=angle_delta(la,anchor_la,anchor_ls || lsquare);
    always @(*) begin
        relative_change=$signed(dl)-$signed(db);
        if(relative_change>180) relative_change=relative_change-360;
        else if(relative_change< -180) relative_change=relative_change+360;
        if(anchor_ls || lsquare) begin
            if(relative_change>90) relative_change=relative_change-180;
            else if(relative_change< -90) relative_change=relative_change+180;
        end
    end
    wire [119:0] next_record={{dl[10],dl},{db[10],db},lh,lw,ly,lx,bh,bw,by,bx};
    function close_center;
        input [11:0] a,b;reg [11:0] d;
        begin d=a>=b?a-b:b-a;close_center=d<=12;end
    endfunction
    function close_side;
        input [11:0] a,b;reg [11:0] d;
        begin d=a>=b?a-b:b-a;close_side=d<=(b>>4)+2;end
    endfunction
    wire consistent=close_center(bx,history0[11:0]) && close_center(by,history0[23:12]) &&
                    close_center(lx,history0[59:48]) && close_center(ly,history0[71:60]) &&
                    close_side(bw,history0[35:24]) && close_side(bh,history0[47:36]) &&
                    close_side(lw,history0[83:72]) && close_side(lh,history0[95:84]) &&
                    db<=3 && db>=-3 && relative_change<=3 && relative_change>=-3;
    wire [11:0] f0=history0[item*12+:12],f1=history1[item*12+:12],f2=history2[item*12+:12];
    wire signed [12:0] a0=item>=8?{f0[11],f0}:{1'b0,f0};
    wire signed [12:0] a1=item>=8?{f1[11],f1}:{1'b0,f1};
    wire signed [12:0] a2=item>=8?{f2[11],f2}:{1'b0,f2};
    wire signed [12:0] median=a0<a1?(a1<a2?a1:(a0<a2?a2:a0)):(a0<a2?a0:(a1<a2?a2:a1));
    reg signed [13:0] angle_sum;
    always @(*) begin
        angle_sum=$signed({1'b0,(item==8?anchor_ba:anchor_la)})+$signed(median);
        if(angle_sum<0) angle_sum=angle_sum+360;
        else if(angle_sum>=360) angle_sum=angle_sum-360;
    end
    assign {O_lh,O_lw,O_ly,O_lx,O_bh,O_bw,O_by,O_bx}=fused[95:0];
    assign O_ba=fused[104:96];assign O_la=fused[116:108];
    task begin_window;
        begin history0<=first_record;anchor_ba<=ba;anchor_la<=la;
            anchor_bs<=bsquare;anchor_ls<=lsquare;count<=1;end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            count<=0;history0<=0;history1<=0;history2<=0;fused<=0;
            anchor_ba<=0;anchor_la<=0;anchor_bs<=0;anchor_ls<=0;second_bs<=0;second_ls<=0;
            item<=0;busy<=0;O_sample<=0;O_valid<=0;O_reason<=0;O_bsquare<=0;O_lsquare<=0;
        end else begin
            O_sample<=0;
            if(!enable) begin count<=0;busy<=0;O_valid<=0;end
            else if(busy) begin
                fused[item*12+:12]<=item>=8?{3'd0,angle_sum[8:0]}:median[11:0];
                if(item==9) begin busy<=0;O_sample<=1;O_valid<=1;O_reason<=0;end
                else item<=item+1'b1;
            end else if(sample) begin
                O_valid<=0;
                if(!valid) begin count<=0;O_sample<=1;O_reason<=reason;end
                else if(count==0 || !consistent) begin
                    begin_window;O_sample<=1;O_reason<=4;
                end else if(count==1) begin
                    history1<=next_record;second_bs<=bsquare;second_ls<=lsquare;count<=2;
                    O_sample<=1;O_reason<=4;
                end else begin
                    history2<=next_record;count<=0;item<=0;busy<=1;
                    O_bsquare<=(anchor_bs && second_bs) || (anchor_bs && bsquare) || (second_bs && bsquare);
                    O_lsquare<=(anchor_ls && second_ls) || (anchor_ls && lsquare) || (second_ls && lsquare);
                end
            end
        end
    end
endmodule
