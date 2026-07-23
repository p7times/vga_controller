//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : triangle_controller
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Controleaza cele 6 coordonate ale triunghiului (x0,y0,x1,y1,x2,y2) direct
//              cu switch-urile de pe Basys3:
//
//                  sw[0] -> x0     sw[1] -> y0
//                  sw[2] -> x1     sw[3] -> y1
//                  sw[4] -> x2     sw[5] -> y2
//
//              Cand switch-ul e sus, coordonata respectiva se plimba (bounce) intre 0 si
//              maxim; cand e jos, ramane inghetata pe ultima pozitie. Viteza e fixa
//              (SPEED_DIV_BITS mai jos, ca local constanta), nu e parametrizabila.
//---------------------------------------------------------------

`timescale 1ns / 1ps

module triangle_controller #(
    parameter H_ACTIVE = 640,   // Rezoluția pe orizontală
    parameter V_ACTIVE = 480    // Rezoluția pe verticală
)(
    input  wire clk,            // Semnal de ceas principal
    input  wire rst,            // Reset asincron (activ pe 0)
    input  wire [5:0] sw,       // switch-uri pentru mișcarea fiecarui varf (coordonate X/Y)

    // Coordonatele generate pentru vârfurile triunghiului
    output reg [$clog2(H_ACTIVE)-1:0] x0,
    output reg [$clog2(V_ACTIVE)-1:0] y0,
    output reg [$clog2(H_ACTIVE)-1:0] x1,
    output reg [$clog2(V_ACTIVE)-1:0] y1,
    output reg [$clog2(H_ACTIVE)-1:0] x2,
    output reg [$clog2(V_ACTIVE)-1:0] y2
);

    localparam SPEED_DIV_BITS = 18; // Contor pentru încetinirea mișcării (~2.6ms la 100MHz per pas)

    // -------------------------------------------------------------------
    // Prescaler / Divizor de ceas (Generează semnalul `tick` pentru mișcare)
    // -------------------------------------------------------------------
    reg [SPEED_DIV_BITS-1:0] div_cnt;
    wire tick = (div_cnt == 0); // Activ la fiecare deversare a contorului

    always @(posedge clk or posedge rst) begin
        if (rst) div_cnt <= 0;
        else     div_cnt <= div_cnt + 1'b1;
    end

    // -------------------------------------------------------------------
    // Registre de direcție (0 = creștere/dreapta/jos, 1 = scădere/stânga/sus)
    // -------------------------------------------------------------------
    reg dir_x0, dir_y0, dir_x1, dir_y1, dir_x2, dir_y2;

    // -------------------------------------------------------------------
    // Logica de actualizare coordonate și detecție ricoșeu
    // -------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // La reset, poziționăm toate cele 3 vârfuri în centrul ecranului
            x0 <= H_ACTIVE/2; y0 <= V_ACTIVE/2;
            x1 <= H_ACTIVE/2; y1 <= V_ACTIVE/2;
            x2 <= H_ACTIVE/2; y2 <= V_ACTIVE/2;

            // Direcțiile inițiale setate pe creștere
            dir_x0 <= 0; dir_y0 <= 0;
            dir_x1 <= 0; dir_y1 <= 0;
            dir_x2 <= 0; dir_y2 <= 0;
        end else if (tick) begin

            // --- Control X0 ---
            if (sw[0]) begin
                if (dir_x0 == 0) begin
                    if (x0 >= H_ACTIVE-1) dir_x0 <= 1; // Schimbă direcția dacă atinge marginea dreaptă
                    else                  x0 <= x0 + 1;
                end else begin
                    if (x0 == 0)          dir_x0 <= 0; // Schimbă direcția dacă atinge marginea stângă
                    else                  x0 <= x0 - 1;
                end
            end

            // --- Control Y0 ---
            if (sw[1]) begin
                if (dir_y0 == 0) begin
                    if (y0 >= V_ACTIVE-1) dir_y0 <= 1; // Ricoșeu jos
                    else                  y0 <= y0 + 1;
                end else begin
                    if (y0 == 0)          dir_y0 <= 0; // Ricoșeu sus
                    else                  y0 <= y0 - 1;
                end
            end

            // --- Control X1 ---
            if (sw[2]) begin
                if (dir_x1 == 0) begin
                    if (x1 >= H_ACTIVE-1) dir_x1 <= 1;
                    else                  x1 <= x1 + 1;
                end else begin
                    if (x1 == 0)          dir_x1 <= 0;
                    else                  x1 <= x1 - 1;
                end
            end

            // --- Control Y1 ---
            if (sw[3]) begin
                if (dir_y1 == 0) begin
                    if (y1 >= V_ACTIVE-1) dir_y1 <= 1;
                    else                  y1 <= y1 + 1;
                end else begin
                    if (y1 == 0)          dir_y1 <= 0;
                    else                  y1 <= y1 - 1;
                end
            end

            // --- Control X2 ---
            if (sw[4]) begin
                if (dir_x2 == 0) begin
                    if (x2 >= H_ACTIVE-1) dir_x2 <= 1;
                    else                  x2 <= x2 + 1;
                end else begin
                    if (x2 == 0)          dir_x2 <= 0;
                    else                  x2 <= x2 - 1;
                end
            end

            // --- Control Y2 ---
            if (sw[5]) begin
                if (dir_y2 == 0) begin
                    if (y2 >= V_ACTIVE-1) dir_y2 <= 1;
                    else                  y2 <= y2 + 1;
                end else begin
                    if (y2 == 0)          dir_y2 <= 0;
                    else                  y2 <= y2 - 1;
                end
            end

        end
    end

endmodule // triangle_controller