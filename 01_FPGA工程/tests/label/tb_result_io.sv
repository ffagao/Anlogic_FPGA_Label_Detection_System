`timescale 1ns/1ps
module tb_result_io;
    reg clk=0;always #5 clk=~clk;
    reg rst_n=0,enable=0,locked=0,muted=0;reg [1:0] result=0;
    wire buzzer,beeping;wire [7:0] sel,dig;
    integer n,j,active_cycles,low_cycles;reg [5:0] seen;
    label_result_io #(.BEEP_CYCLES(24),.TONE_CYCLES(2),.SCAN_CYCLES(8)) dut(
        .clk(clk),.rst_n(rst_n),.enable(enable),.locked(locked),.muted(muted),.result(result),
        .buzzer_n(buzzer),.beeping(beeping),.seg_sel(sel),.seg_dig(dig));
    function [7:0] expected;
        input [1:0] r;input integer digit;
        begin expected=255;
            case(r)
            1:case(digit) 3:expected='h8c;2:expected='h88;1,0:expected='h92;default:;endcase
            2:case(digit) 3:expected='h8e;2:expected='h88;1:expected='hf9;0:expected='hc7;default:;endcase
            3:case(digit) 1:expected='hc1;0:expected='hc8;default:;endcase
            default:;
            endcase
        end
    endfunction
    task new_result;
        input [1:0] r;
        begin @(negedge clk);locked=0;result=0;repeat(4) @(negedge clk);
            result=r;locked=1;end
    endtask
    task check_scan;
        input [1:0] r;
        begin seen=0;
            repeat(150) begin
                @(negedge clk);
                if(sel!=255) begin
                    if((~sel & ((~sel)-1)) & 8'hff) $fatal(1,"more than one digit enabled: %h",sel);
                    if(sel[7:6]!=3) $fatal(1,"unused upper digits enabled");
                    for(j=0;j<6;j=j+1) if(!sel[j]) begin
                        if(dig!==expected(r,j) || dig==255) $fatal(1,"incorrect result glyph r=%d digit=%d DIG=%h",r,j,dig);
                        if(r==3 && j==1 && dig[1]) $fatal(1,"U must light its upper vertical segment");
                        if(r==3 && j==0 && dig[0]) $fatal(1,"N approximation must reach the top segment");
                        seen[j]=1;
                    end
                end
                if(r!=2 && !buzzer) $fatal(1,"PASS/UNKNOWN must not sound");
            end
            if(seen!==(r==3?6'b000011:6'b001111)) $fatal(1,"word is not right aligned: %b",seen);
        end
    endtask
    initial begin
        repeat(4) @(negedge clk);rst_n=1;enable=1;repeat(4) @(negedge clk);
        if(sel!=255 || dig!=255 || !buzzer) $fatal(1,"idle not blank/silent");
        new_result(1);check_scan(1);
        new_result(2);active_cycles=0;low_cycles=0;
        repeat(100) begin @(negedge clk);if(beeping) active_cycles=active_cycles+1;if(!buzzer) low_cycles=low_cycles+1;end
        if(active_cycles!=24 || low_cycles==0 || beeping) $fatal(1,"FAIL did not sound exactly once for 24 test clocks: %d",active_cycles);
        check_scan(2);
        if(beeping || !buzzer) $fatal(1,"FAIL retriggered while holding result");
        new_result(2);repeat(5) @(negedge clk);if(!beeping) $fatal(1,"next FAIL did not rearm");
        muted=1;repeat(3) @(negedge clk);if(beeping || !buzzer) $fatal(1,"mute did not stop alarm");
        muted=0;repeat(40) @(negedge clk);if(beeping) $fatal(1,"unmute retriggered old failure");
        new_result(3);check_scan(3);
        new_result(2);repeat(5) @(negedge clk);if(!beeping) $fatal(1,"FAIL did not trigger before mode-exit test");
        enable=0;repeat(3) @(negedge clk);if(sel!=255 || dig!=255 || !buzzer) $fatal(1,"mode exit not blank/silent");
        enable=1;repeat(60) begin @(negedge clk);if(beeping || !buzzer) $fatal(1,"mode reentry retriggered stale FAIL");end
        $display("PASS tb_result_io: PASS/FAIL/un glyphs, active-low multiplex, blank digits, one-shot duration, rearm, mute and no stale FAIL on mode reentry");
        $finish;
    end
endmodule
