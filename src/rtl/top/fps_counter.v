//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : fps_counter
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Afișor pentru FPS. Acesta numără la fiecare secundă
//              câte pulsuri frame_done sunt declanșate.
//---------------------------------------------------------------

`timescale 1ns / 1ps

module fps_counter (
    input  wire       clk,   // Ceas
    input  wire       rst_n, // Reset asincron, activ în 0
    input  wire       vsync, // Semnalul de sincronizare
    output reg  [3:0] an,    // Anozi pentru afișaj (activ în 0)
    output reg  [6:0] seg,   // Catozi pentru segmente (activ în 0)
    output wire       dp     // Punctul zecimal
);

    // Pe Basys3, afișajul este activ pe 0 logic. Pentru a ține DP stins mereu, îl setăm pe 1.
    assign dp = 1'b1;

    // =========================================================
    // 1. Timer de 1 Secundă
    // =========================================================
    reg [26:0] sec_count;
    wire sec_tick;

    assign sec_tick = (sec_count == 27'd25_173_009);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sec_count <= 27'd0;
        end else if (sec_tick) begin
            sec_count <= 27'd0;
        end else begin
            sec_count <= sec_count + 1'b1;
        end
    end

    // =========================================================
    // 2. Detector de front crescător pentru VSYNC
    // =========================================================
    reg vsync_d1;
    reg vsync_d2;
    wire vsync_pulse;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vsync_d1 <= 1'b0;
            vsync_d2 <= 1'b0;
        end else begin
            vsync_d1 <= vsync;
            vsync_d2 <= vsync_d1;
        end
    end
    
    // Puls care durează exact un ciclu de ceas când vsync trece din 0 în 1
    assign vsync_pulse = vsync_d1 & ~vsync_d2;

    // =========================================================
    // 3. Numărător BCD (Unități și Zeci) și Registrul de Salvare
    // =========================================================
    reg [3:0] count_u, count_t; // Numărătoare curente
    reg [3:0] freq_u, freq_t;   // Registrele în care salvăm la fiecare secundă

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_u <= 4'd0;
            count_t <= 4'd0;
            freq_u  <= 4'd0;
            freq_t  <= 4'd0;
        end else if (sec_tick) begin
            // La finalul secundei, salvăm valoarea
            freq_u <= count_u;
            freq_t <= count_t;
            
            // Resetăm numărătorul pentru secunda următoare
            // Dacă apare un puls vsync fix în acest moment, îl punem ca prima valoare
            if (vsync_pulse) begin
                count_u <= 4'd1;
                count_t <= 4'd0;
            end else begin
                count_u <= 4'd0;
                count_t <= 4'd0;
            end
        end else if (vsync_pulse) begin
            // Incrementăm numărătorul BCD
            if (count_u == 4'd9) begin
                count_u <= 4'd0;
                if (count_t == 4'd9) begin
                    count_t <= 4'd0; // Overlap după 99
                end else begin
                    count_t <= count_t + 1'b1;
                end
            end else begin
                count_u <= count_u + 1'b1;
            end
        end
    end

    // =========================================================
    // 4. Multiplexarea Afișajului cu 7 Segmente
    // =========================================================
    // Folosim un numărător pentru a schimba rapid cifrele afișate (~760 Hz)
    reg [16:0] refresh_count;
    wire digit_sel;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            refresh_count <= 17'd0;
        end else begin
            refresh_count <= refresh_count + 1'b1;
        end
    end

    // Folosim cel mai semnificativ bit din numărător pentru a alterna cifrele
    assign digit_sel = refresh_count[16];

    reg [3:0] current_digit;

    always @(*) begin
        case (digit_sel)
            1'b0: begin
                an = 4'b1110;         // Activăm doar ultimul digit (unitățile)
                current_digit = freq_u;
            end
            1'b1: begin
                an = 4'b1101;         // Activăm penultimul digit (zecile)
                current_digit = freq_t;
            end
        endcase
    end

    // =========================================================
    // 5. Decodor BCD -> 7 Segmente (Catozi activi în 0)
    // =========================================================
    always @(*) begin
        case (current_digit)
            // Forma biților: GFEDCBA (0 înseamnă segment aprins)
            4'd0: seg = 7'b1000000;
            4'd1: seg = 7'b1111001;
            4'd2: seg = 7'b0100100;
            4'd3: seg = 7'b0110000;
            4'd4: seg = 7'b0011001;
            4'd5: seg = 7'b0010010;
            4'd6: seg = 7'b0000010;
            4'd7: seg = 7'b1111000;
            4'd8: seg = 7'b0000000;
            4'd9: seg = 7'b0010000;
            default: seg = 7'b1111111; // Toate stinse pentru orice altă valoare
        endcase
    end

endmodule // fps_counter
