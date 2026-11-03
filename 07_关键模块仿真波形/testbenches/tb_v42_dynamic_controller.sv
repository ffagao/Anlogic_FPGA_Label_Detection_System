`timescale 1ns/1ps
module tb_v42_dynamic_controller;
    reg clk=0,rst_n=0,enable=0,auto_mode=1,start=0,learn=0,ack=0,clear=0,sample=0,valid=0;
    reg [3:0] reason=0; reg signed [12:0] u=0,v=0; reg [12:0] wr=273,hr=205;
    reg [8:0] alpha=0; reg [11:0] bx=900,by=360,bw=512,bh=256,lx=900,ly=360,lw=80,lh=40;
    reg [8:0] ba=0,la=0; reg bsquare=0,lsquare=0;
    wire [1:0] state,result; wire [3:0] cause; wire [2:0] fail; wire locked,geometry,reference_set,learn_failed;
    wire [1:0] size_fail; wire O_alarm,muted; wire signed [12:0] ref_u,ref_v,du,dv;
    wire [12:0] ref_wr,ref_hr; wire [8:0] ref_alpha; wire ref_square,ref_label_square;
    wire [11:0] ref_bw,ref_bh,box_x,box_y,box_w,box_h,label_x,label_y,label_w,label_h;
    wire [8:0] box_a,label_a; wire box_square,scene; wire [1:0] branch,main_item;
    wire [23:0] total,passes,fails,unknowns;
    always #5 clk=~clk;
    label_scene_controller #(.TIMEOUT_CYCLES(1000),.AUTO_WAIT_CYCLES(8),.AUTO_INTERVAL_CYCLES(3),.AUTO_DEADLINE_CYCLES(250)) dut(
        .clk(clk),.rst_n(rst_n),.enable(enable),.auto_mode(auto_mode),.start(start),.learn(learn),.ack(ack),.clear(clear),.sample(sample),.valid(valid),
        .reason(reason),.u(u),.v(v),.wr(wr),.hr(hr),.alpha(alpha),.bx(bx),.by(by),.bw(bw),.bh(bh),.lx(lx),.ly(ly),.lw(lw),.lh(lh),.ba(ba),.la(la),.bsquare(bsquare),.lsquare(lsquare),
        .state(state),.result(result),.cause(cause),.fail(fail),.locked(locked),.geometry(geometry),.reference_set(reference_set),.learn_failed(learn_failed),.size_fail(size_fail),.O_alarm(O_alarm),.muted(muted),
        .ref_u(ref_u),.ref_v(ref_v),.du(du),.dv(dv),.ref_wr(ref_wr),.ref_hr(ref_hr),.ref_alpha(ref_alpha),.ref_square(ref_square),.ref_label_square(ref_label_square),.ref_bw(ref_bw),.ref_bh(ref_bh),
        .da(),.box_x(box_x),.box_y(box_y),.box_w(box_w),.box_h(box_h),.label_x(label_x),.label_y(label_y),.label_w(label_w),.label_h(label_h),.box_a(box_a),.label_a(label_a),.box_square(box_square),.scene(scene),.branch(branch),.main_item(main_item),.total(total),.passes(passes),.fails(fails),.unknowns(unknowns));
    task automatic offer_valid;
        input integer shift;
        begin
            @(negedge clk); bx<=900+shift;lx<=900+shift;sample<=1;valid<=1;
            @(negedge clk); sample<=0;valid<=0;
        end
    endtask
    task automatic offer_invalid;
        begin
            @(negedge clk);sample<=1;valid<=0;reason<=4'd7;
            @(negedge clk);sample<=0;
        end
    endtask
    integer i;
    initial begin
        repeat(3) @(negedge clk); rst_n<=1;enable<=1;
        // Preserve the original learning operation.
        @(negedge clk);learn<=1;
        @(negedge clk);learn<=0;sample<=1;valid<=1;
        @(negedge clk);sample<=0;valid<=0;
        wait(reference_set); wait(state==1);
        // First complete box starts the 500 ms wait (scaled to 8 cycles here).
        offer_valid(0);
        if(dut.auto_phase!=0) $fatal(1,"single detection started waiting");
        offer_valid(2);
        repeat(12) @(negedge clk);
        // Ten spaced observations with a common screen translation.
        for(i=0;i<5;i=i+1) begin
            repeat(15) @(negedge clk); offer_valid(i*2);
            if(i==1) begin reason=1; @(negedge clk);sample=1;valid=0;@(negedge clk);sample=0; end
        end
        repeat(15) @(negedge clk);
        if(!locked || result!=2'd1 || total!=24'h000001 || passes!=24'h000001 || fails!=0 || unknowns!=0)
            $fatal(1,"dynamic PASS vote/lock failed: state=%0d result=%0d locked=%0d total=%0d passes=%0d",state,result,locked,total,passes);
        // A locked result is not changed by valid motion observations.
        offer_valid(40);
        if(!locked || result!=2'd1) $fatal(1,"locked result changed while target remained");
        // Three lost observations re-arm the next carton.
        offer_invalid(); offer_invalid(); offer_invalid();
        repeat(2) @(negedge clk);
        if(locked || result!=0) $fatal(1,"target-loss rearm failed");
        offer_valid(0);
        offer_valid(2);
        repeat(260) @(negedge clk);
        if(!locked || result!=3 || unknowns!=24'h000001) $fatal(1,"deadline did not latch UNKNOWN");
        $display("PASS tb_v42_dynamic_controller: learning, intermittent invalid, five samples, motion, lock and rearm");
        $finish;
    end
    initial begin #200000;$fatal(1,"dynamic controller timeout"); end
endmodule
