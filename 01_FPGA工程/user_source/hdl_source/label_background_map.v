// Explicit EMPTY-scene calibration. One RGB mean per 16x16 tile, averaged
// over eight fresh sensor IDs. No requirement that different tiles agree.
// The table remains frozen until a new calibration or mode exit.
module label_background_map #(
    parameter integer WIDTH=1280,HEIGHT=720,REGION_L=0,TIMEOUT_CYCLES=375000000,
    FRAME_DELTA=48
)(input wire clk,rst_n,enable,start,imaging_locked,de,
  input wire [11:0] x,y,input wire [23:0] rgb,frame_id,
  output reg ready,busy,failed,output reg [3:0] progress,
  output reg [23:0] lookup_rgb);
    // REGION_L and REGION_WIDTH must be multiples of the 16-pixel tile size.
    localparam REGION_WIDTH=WIDTH-REGION_L;
    localparam COLS=REGION_WIDTH/16,ROWS=HEIGHT/16,CELLS=COLS*ROWS;
    localparam ACTIVE_PIXELS=REGION_WIDTH*HEIGHT;
    localparam MAX_BAD=CELLS/100>0?CELLS/100:0;
    (* ram_style="block" *) reg [23:0] reference[0:CELLS-1];
    (* ram_style="block" *) reg [23:0] previous[0:CELLS-1];
    (* ram_style="block" *) reg [32:0] totals[0:CELLS-1];
    (* ram_style="block" *) reg [47:0] column_sum[0:COLS-1];
    reg [23:0] previous_q;reg [32:0] totals_q;reg [47:0] column_q;
    wire in_region=x>=REGION_L;
    wire [11:0] region_x=in_region?x-REGION_L:12'd0;
    wire [12:0] addr=(y>>4)*COLS+(region_x>>4);
    wire [12:0] safe_addr=in_region && addr<CELLS?addr:13'd0;
    wire [12:0] safe_col=(region_x>>4)<COLS?region_x>>4:13'd0;
    always @(posedge clk) begin
        lookup_rgb<=reference[safe_addr];
        previous_q<=previous[safe_addr];totals_q<=totals[safe_addr];
        column_q<=column_sum[safe_col];
    end
    reg collecting,seen;
    reg [23:0] last_id;
    reg [2:0] settle;
    reg [28:0] timer;
    reg [20:0] pixels;
    reg [12:0] tiles,bad_tiles;
    reg [11:0] hr,hg,hb;
    wire fresh=!seen || frame_id!=last_id;
    wire [15:0] sum_r=(y[3:0]==0?16'd0:column_q[47:32])+{4'd0,hr}+rgb[23:16];
    wire [15:0] sum_g=(y[3:0]==0?16'd0:column_q[31:16])+{4'd0,hg}+rgb[15:8];
    wire [15:0] sum_b=(y[3:0]==0?16'd0:column_q[15:0])+{4'd0,hb}+rgb[7:0];
    wire [23:0] mean={sum_r[15:8],sum_g[15:8],sum_b[15:8]};
    wire [7:0] dr=mean[23:16]>=previous_q[23:16]?mean[23:16]-previous_q[23:16]:previous_q[23:16]-mean[23:16];
    wire [7:0] dg=mean[15:8]>=previous_q[15:8]?mean[15:8]-previous_q[15:8]:previous_q[15:8]-mean[15:8];
    wire [7:0] db=mean[7:0]>=previous_q[7:0]?mean[7:0]-previous_q[7:0]:previous_q[7:0]-mean[7:0];
    wire changed=progress!=0 && ({2'b0,dr}+{2'b0,dg}+{2'b0,db}>FRAME_DELTA);
    wire [10:0] tr=(progress==0?11'd0:totals_q[32:22])+{3'd0,mean[23:16]};
    wire [10:0] tg=(progress==0?11'd0:totals_q[21:11])+{3'd0,mean[15:8]};
    wire [10:0] tb=(progress==0?11'd0:totals_q[10:0])+{3'd0,mean[7:0]};
    task reject;
        begin ready<=0;busy<=0;collecting<=0;failed<=1;end
    endtask
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin ready<=0;busy<=0;failed<=0;progress<=0;collecting<=0;seen<=0;
            last_id<=0;settle<=0;timer<=0;pixels<=0;tiles<=0;bad_tiles<=0;hr<=0;hg<=0;hb<=0;end
        else if(!enable || !imaging_locked) begin
            ready<=0;busy<=0;collecting<=0;seen<=0;failed<=0;progress<=0;
        end else if(start && !busy) begin
            ready<=0;busy<=1;failed<=0;progress<=0;collecting<=0;seen<=0;settle<=0;timer<=0;
        end else if(busy) begin
            timer<=timer+1'b1;
            if(timer==TIMEOUT_CYCLES-1) reject;
            else begin
                if(de && x==0 && y==0) begin
                    if(collecting) reject;
                    else if(fresh) begin
                        seen<=1;last_id<=frame_id;
                        // Discard three complete display IDs after the lock.
                        // This covers the camera/ISP/DDR pipeline settling.
                        if(settle<3) settle<=settle+1'b1;
                        else begin collecting<=1;pixels<=REGION_L==0?1:0;tiles<=0;bad_tiles<=0;
                            hr<=REGION_L==0?rgb[23:16]:0;
                            hg<=REGION_L==0?rgb[15:8]:0;
                            hb<=REGION_L==0?rgb[7:0]:0;end
                    end
                end else if(collecting && de) begin
                    if(in_region) begin
                    pixels<=pixels+1'b1;
                    if(region_x[3:0]==0) begin hr<=rgb[23:16];hg<=rgb[15:8];hb<=rgb[7:0];end
                    else if(region_x[3:0]==15) begin hr<=0;hg<=0;hb<=0;end
                    else begin hr<=hr+rgb[23:16];hg<=hg+rgb[15:8];hb<=hb+rgb[7:0];end
                    if(region_x[3:0]==15) begin
                        column_sum[region_x>>4]<={sum_r,sum_g,sum_b};
                        if(y[3:0]==15) begin
                            previous[addr]<=mean;totals[addr]<={tr,tg,tb};
                            tiles<=tiles+1'b1;if(changed) bad_tiles<=bad_tiles+1'b1;
                            if(progress==7) reference[addr]<={tr[10:3],tg[10:3],tb[10:3]};
                        end
                    end
                    end
                    if(x==WIDTH-1 && y==HEIGHT-1) begin
                        collecting<=0;
                        if(pixels!=ACTIVE_PIXELS-1 || tiles!=CELLS-1 ||
                           bad_tiles+(changed?1:0)>MAX_BAD) reject;
                        else if(progress==7) begin ready<=1;busy<=0;progress<=8;end
                        else progress<=progress+1'b1;
                    end
                end
            end
        end
    end
endmodule
