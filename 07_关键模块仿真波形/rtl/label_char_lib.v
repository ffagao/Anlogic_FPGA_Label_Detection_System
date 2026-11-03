module label_char_lib (
    input  wire [7:0]  I_char,
    input  wire [3:0]  I_row,
    output reg  [15:0] O_row_bits
);

    localparam CHAR_AN = 8'h80;
    localparam CHAR_LU = 8'h81;

    reg [34:0] S_bitmap;
    reg [4:0]  S_row5;
    reg        S_ascii;

    // All Latin letters, digits and punctuation use one 5x7 source font.
    // Each source pixel expands to 2x2 inside a 16x16 character cell.
    always @(*) begin
        S_bitmap   = 35'd0;
        S_row5     = 5'd0;
        S_ascii    = 1'b1;
        O_row_bits = 16'd0;

        case(I_char)
            8'h41: S_bitmap = {5'b01110,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001}; // A
            8'h42: S_bitmap = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10001,5'b10001,5'b11110}; // B
            8'h43: S_bitmap = {5'b01110,5'b10001,5'b10000,5'b10000,5'b10000,5'b10001,5'b01110}; // C
            8'h44: S_bitmap = {5'b11110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b11110}; // D
            8'h45: S_bitmap = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b11111}; // E
            8'h46: S_bitmap = {5'b11111,5'b10000,5'b10000,5'b11110,5'b10000,5'b10000,5'b10000}; // F
            8'h47: S_bitmap = {5'b01110,5'b10001,5'b10000,5'b10111,5'b10001,5'b10001,5'b01110}; // G
            8'h48: S_bitmap = {5'b10001,5'b10001,5'b10001,5'b11111,5'b10001,5'b10001,5'b10001}; // H
            8'h49: S_bitmap = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b11111}; // I
            8'h4a: S_bitmap = {5'b00111,5'b00010,5'b00010,5'b00010,5'b10010,5'b10010,5'b01100}; // J
            8'h4b: S_bitmap = {5'b10001,5'b10010,5'b10100,5'b11000,5'b10100,5'b10010,5'b10001}; // K
            8'h4c: S_bitmap = {5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b10000,5'b11111}; // L
            8'h4d: S_bitmap = {5'b10001,5'b11011,5'b10101,5'b10101,5'b10001,5'b10001,5'b10001}; // M
            8'h4e: S_bitmap = {5'b10001,5'b11001,5'b10101,5'b10011,5'b10001,5'b10001,5'b10001}; // N
            8'h4f: S_bitmap = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // O
            8'h50: S_bitmap = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10000,5'b10000,5'b10000}; // P
            8'h51: S_bitmap = {5'b01110,5'b10001,5'b10001,5'b10001,5'b10101,5'b10010,5'b01101}; // Q
            8'h52: S_bitmap = {5'b11110,5'b10001,5'b10001,5'b11110,5'b10100,5'b10010,5'b10001}; // R
            8'h53: S_bitmap = {5'b01111,5'b10000,5'b10000,5'b01110,5'b00001,5'b00001,5'b11110}; // S
            8'h54: S_bitmap = {5'b11111,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100,5'b00100}; // T
            8'h55: S_bitmap = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01110}; // U
            8'h56: S_bitmap = {5'b10001,5'b10001,5'b10001,5'b10001,5'b10001,5'b01010,5'b00100}; // V
            8'h57: S_bitmap = {5'b10001,5'b10001,5'b10001,5'b10101,5'b10101,5'b10101,5'b01010}; // W
            8'h58: S_bitmap = {5'b10001,5'b10001,5'b01010,5'b00100,5'b01010,5'b10001,5'b10001}; // X
            8'h59: S_bitmap = {5'b10001,5'b10001,5'b01010,5'b00100,5'b00100,5'b00100,5'b00100}; // Y
            8'h5a: S_bitmap = {5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b10000,5'b11111}; // Z
            8'h30: S_bitmap = {5'b01110,5'b10001,5'b10011,5'b10101,5'b11001,5'b10001,5'b01110}; // 0
            8'h31: S_bitmap = {5'b00100,5'b01100,5'b00100,5'b00100,5'b00100,5'b00100,5'b01110}; // 1
            8'h32: S_bitmap = {5'b01110,5'b10001,5'b00001,5'b00010,5'b00100,5'b01000,5'b11111}; // 2
            8'h33: S_bitmap = {5'b11110,5'b00001,5'b00001,5'b01110,5'b00001,5'b00001,5'b11110}; // 3
            8'h34: S_bitmap = {5'b00010,5'b00110,5'b01010,5'b10010,5'b11111,5'b00010,5'b00010}; // 4
            8'h35: S_bitmap = {5'b11111,5'b10000,5'b10000,5'b11110,5'b00001,5'b00001,5'b11110}; // 5
            8'h36: S_bitmap = {5'b01110,5'b10000,5'b10000,5'b11110,5'b10001,5'b10001,5'b01110}; // 6
            8'h37: S_bitmap = {5'b11111,5'b00001,5'b00010,5'b00100,5'b01000,5'b01000,5'b01000}; // 7
            8'h38: S_bitmap = {5'b01110,5'b10001,5'b10001,5'b01110,5'b10001,5'b10001,5'b01110}; // 8
            8'h39: S_bitmap = {5'b01110,5'b10001,5'b10001,5'b01111,5'b00001,5'b00001,5'b01110}; // 9
            8'h3a: S_bitmap = {5'b00000,5'b00100,5'b00100,5'b00000,5'b00100,5'b00100,5'b00000}; // :
            8'h2b: S_bitmap = {5'b00000,5'b00100,5'b00100,5'b11111,5'b00100,5'b00100,5'b00000}; // +
            8'h2d: S_bitmap = {5'b00000,5'b00000,5'b00000,5'b11111,5'b00000,5'b00000,5'b00000}; // -
            8'h2e: S_bitmap = {5'b00000,5'b00000,5'b00000,5'b00000,5'b00000,5'b00100,5'b00100}; // .
            8'h2f: S_bitmap = {5'b00001,5'b00010,5'b00010,5'b00100,5'b01000,5'b01000,5'b10000}; // /
            CHAR_AN: begin
                S_ascii = 1'b0;
                case(I_row)
                    4'd0:  O_row_bits = 16'h0200;
                    4'd1:  O_row_bits = 16'h0100;
                    4'd2:  O_row_bits = 16'h3ffc;
                    4'd3:  O_row_bits = 16'h2004;
                    4'd4:  O_row_bits = 16'h4208;
                    4'd5:  O_row_bits = 16'h0200;
                    4'd6:  O_row_bits = 16'h0200;
                    4'd7:  O_row_bits = 16'hfffe;
                    4'd8:  O_row_bits = 16'h0420;
                    4'd9:  O_row_bits = 16'h0820;
                    4'd10: O_row_bits = 16'h1840;
                    4'd11: O_row_bits = 16'h0640;
                    4'd12: O_row_bits = 16'h0180;
                    4'd13: O_row_bits = 16'h0260;
                    4'd14: O_row_bits = 16'h0c10;
                    4'd15: O_row_bits = 16'h7008;
                endcase
            end
            CHAR_LU: begin
                S_ascii = 1'b0;
                case(I_row)
                    4'd0:  O_row_bits = 16'h0040;
                    4'd1:  O_row_bits = 16'h7c40;
                    4'd2:  O_row_bits = 16'h4478;
                    4'd3:  O_row_bits = 16'h4488;
                    4'd4:  O_row_bits = 16'h4550;
                    4'd5:  O_row_bits = 16'h7c20;
                    4'd6:  O_row_bits = 16'h1050;
                    4'd7:  O_row_bits = 16'h1088;
                    4'd8:  O_row_bits = 16'h1106;
                    4'd9:  O_row_bits = 16'h5cf8;
                    4'd10: O_row_bits = 16'h5088;
                    4'd11: O_row_bits = 16'h5088;
                    4'd12: O_row_bits = 16'h5088;
                    4'd13: O_row_bits = 16'h5c88;
                    4'd14: O_row_bits = 16'he0f8;
                    4'd15: O_row_bits = 16'h0088;
                endcase
            end
            default: S_bitmap = 35'd0;
        endcase

        if(S_ascii) begin
            case(I_row)
                4'd1,  4'd2:  S_row5 = S_bitmap[34:30];
                4'd3,  4'd4:  S_row5 = S_bitmap[29:25];
                4'd5,  4'd6:  S_row5 = S_bitmap[24:20];
                4'd7,  4'd8:  S_row5 = S_bitmap[19:15];
                4'd9,  4'd10: S_row5 = S_bitmap[14:10];
                4'd11, 4'd12: S_row5 = S_bitmap[9:5];
                4'd13, 4'd14: S_row5 = S_bitmap[4:0];
                default:      S_row5 = 5'd0;
            endcase
            O_row_bits = {2'b00,
                          S_row5[4], S_row5[4],
                          S_row5[3], S_row5[3],
                          S_row5[2], S_row5[2],
                          S_row5[1], S_row5[1],
                          S_row5[0], S_row5[0],
                          4'b0000};
        end
    end

endmodule
