// Streaming 4-connected regions in the existing 8x8 frame-difference mask.
// Up to 7 labels; overflow is explicit and the count must not be trusted.
module motion_region_counter #(
 parameter integer GRID_WIDTH=160, MIN_BLOCKS=4
)(input wire clk,rst_n,enable,frame_start,publish,frame_ok,block_valid,changed,
  input wire [7:0] block_x,input wire [6:0] block_y,
  output reg [4:0] region_count,output reg count_valid,overflow);
 reg [2:0] previous_row[0:GRID_WIDTH-1];
 reg [2:0] parent[0:7];reg [13:0] area[0:7];reg [7:0] used;
 reg [2:0] left_label;reg overflow_work;
 reg [2:0] up_id,left_id,root_up,root_left,new_id,chosen,other;
 reg [4:0] completed;integer i;
 always @* begin
  up_id=(block_y==0 || block_x>=GRID_WIDTH)?0:previous_row[block_x];
  left_id=block_x==0?0:left_label;
  root_up=up_id==0?0:parent[up_id];root_left=left_id==0?0:parent[left_id];
  new_id=0;
  for(integer j=7;j>=1;j=j-1) if(!used[j])new_id=j;
  chosen=0;other=0;
  if(root_left!=0 && root_up!=0) begin
   chosen=root_left<root_up?root_left:root_up;
   other=root_left<root_up?root_up:root_left;
  end else if(root_left!=0)chosen=root_left;
  else if(root_up!=0)chosen=root_up;
  else chosen=new_id;
  completed=0;
  for(integer j=1;j<8;j=j+1)
   if(used[j] && parent[j]==j && area[j]>=MIN_BLOCKS)completed=completed+1'b1;
 end
 always @(posedge clk or negedge rst_n) begin
  if(!rst_n) begin
   region_count<=0;count_valid<=0;overflow<=0;overflow_work<=0;used<=0;left_label<=0;
   for(i=0;i<8;i=i+1)begin parent[i]<=0;area[i]<=0;end
  end else if(!enable) begin
   count_valid<=0;overflow<=0;overflow_work<=0;used<=0;left_label<=0;
  end else if(frame_start) begin
   if(publish)begin region_count<=completed;overflow<=overflow_work;count_valid<=frame_ok && !overflow_work;end
   used<=0;left_label<=0;overflow_work<=0;
   for(i=0;i<8;i=i+1)begin parent[i]<=i;area[i]<=0;end
  end else if(block_valid && block_x<GRID_WIDTH) begin
   if(!changed)begin previous_row[block_x]<=0;left_label<=0;end
   else if(chosen==0)begin previous_row[block_x]<=0;left_label<=0;overflow_work<=1;end
   else begin
    previous_row[block_x]<=chosen;left_label<=chosen;
    if(root_left==0 && root_up==0)begin used[chosen]<=1;parent[chosen]<=chosen;area[chosen]<=1;end
    else if(other!=0 && other!=chosen)begin
     area[chosen]<=area[chosen]+area[other]+1'b1;area[other]<=0;
     for(i=1;i<8;i=i+1)if(used[i] && parent[i]==other)parent[i]<=chosen;
    end else if(area[chosen]!=14'h3fff)area[chosen]<=area[chosen]+1'b1;
   end
  end
 end
endmodule
