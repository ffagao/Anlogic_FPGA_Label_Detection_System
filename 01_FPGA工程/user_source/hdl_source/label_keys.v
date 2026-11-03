// Active-low keys. A held key on mode entry must be released first.
module label_keys #(
    parameter integer DEBOUNCE_CYCLES = 1500000,
    parameter integer HOLD_CYCLES = 75000000
)(
    input wire I_clk, I_rst_n, I_enable,
    input wire [3:0] I_keys_n,
    output reg [2:0] O_press,
    output reg O_clear,
    output reg O_background
);
    reg [3:0] meta, sync, stable, armed;
    reg [20:0] debounce [0:3];
    reg [26:0] held;
    reg hold_sent;
    reg hold_armed;
    integer k;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            meta <= 4'hf; sync <= 4'hf; stable <= 4'hf;
            armed <= 0; O_press <= 0; O_clear <= 0; O_background <= 0;
            held <= 0; hold_sent <= 0; hold_armed <= 0;
            for(k=0;k<4;k=k+1) debounce[k] <= 0;
        end else begin
            meta <= I_keys_n; sync <= meta;
            O_press <= 0; O_clear <= 0; O_background <= 0;
            for(k=0;k<4;k=k+1) begin
                if(!I_enable) begin
                    debounce[k] <= 0; stable[k] <= sync[k]; armed[k] <= 0;
                end else if(sync[k] != stable[k]) begin
                    if(debounce[k] == DEBOUNCE_CYCLES-1) begin
                        debounce[k] <= 0; stable[k] <= sync[k];
                        if(sync[k]) armed[k] <= 1;
                        else begin
                            if(k<3 && armed[k]) O_press[k] <= 1;
                            armed[k] <= 0;
                        end
                    end else debounce[k] <= debounce[k]+1'b1;
                end else begin
                    debounce[k] <= 0;
                    if(stable[k]) armed[k] <= 1;
                end
            end
            if(!I_enable) begin held <= 0; hold_sent <= 0; hold_armed <= 0; end
            else if(stable[3] && !sync[3] && debounce[3]==DEBOUNCE_CYCLES-1 && armed[3]) begin
                held <= 0; hold_sent <= 0; hold_armed <= 1;
            end
            else if(!stable[3] && sync[3] && debounce[3]==DEBOUNCE_CYCLES-1) begin
                if(hold_armed && !hold_sent) O_background<=1;
                held<=0;hold_sent<=0;hold_armed<=0;
            end
            else if(stable[3]) begin held <= 0; hold_sent <= 0; hold_armed <= 0; end
            else if(hold_armed && !hold_sent) begin
                if(held == HOLD_CYCLES-1) begin O_clear <= 1; hold_sent <= 1; end
                else held <= held+1'b1;
            end
        end
    end
endmodule
