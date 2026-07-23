//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : bounding_box
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Primeste cele 3 varfuri ale unui triunghi (ca si coordonate semnate, fara parte
//              fractionara) si calculeaza dreptunghiul minim care il incadreaza
//              (bounding box), limitat la dimensiunea ecranului.
//---------------------------------------------------------------

`timescale 1ns / 1ps

module bounding_box #(
    parameter SCREEN_W = 640,                                 // Lungimea ecranului in pixeli
    parameter SCREEN_H = 480,                                 // Latimea ecranului in pixeli
    parameter COORD_W  = $clog2(SCREEN_W) + 1                 // Numarul de biti necesar pentru reprezentarea semnata a coordonatelor
)(
    // Intrare: coordonatele X si Y ale celor 3 varfuri ale triunghiului (semnate)
    input  signed [COORD_W-1:0] x0, y0,
    input  signed [COORD_W-1:0] x1, y1,
    input  signed [COORD_W-1:0] x2, y2,

    // Iesire: coordonatele X,Y minime si maxime ale dreptunghiului de incadrare
    output signed [COORD_W-1:0] min_x, max_x,
    output signed [COORD_W-1:0] min_y, max_y
);

    // Definirea limitei maxime pe axele X,Y
    localparam [COORD_W-1:0]    MAX_X = SCREEN_W - 1;
    localparam [COORD_W-1:0]    MAX_Y = SCREEN_H - 1;

    // -------------------------------------------------------------------
    // Min/Max brut (fara clamp), folosind comparatori ternari
    // -------------------------------------------------------------------
    // Determinarea valorii minime/maxime dintre x0, x1 si x2 folosind operatorul ternar
    wire signed [COORD_W-1:0]   min_x_raw = (x0 < x1) ? ((x0 < x2) ? x0 : x2) : ((x1 < x2) ? x1 : x2);
    wire signed [COORD_W-1:0]   max_x_raw = (x0 > x1) ? ((x0 > x2) ? x0 : x2) : ((x1 > x2) ? x1 : x2);

    // Determinarea valorii minime/maxime dintre y0, y1 si y2 folosind operatorul ternar
    wire signed [COORD_W-1:0]   min_y_raw = (y0 < y1) ? ((y0 < y2) ? y0 : y2) : ((y1 < y2) ? y1 : y2);
    wire signed [COORD_W-1:0]   max_y_raw = (y0 > y1) ? ((y0 > y2) ? y0 : y2) : ((y1 > y2) ? y1 : y2);

    // -------------------------------------------------------------------
    // Clamping (limitare la dimensiunea ecranului), ca sa nu iesim din ecran
    // -------------------------------------------------------------------
    // Limitarea valorii min_x/max_x in intervalul [0, MAX_X]
    assign min_x = (min_x_raw < 0) ? 0 : ((min_x_raw > MAX_X) ? MAX_X : min_x_raw);
    assign max_x = (max_x_raw < 0) ? 0 : ((max_x_raw > MAX_X) ? MAX_X : max_x_raw);

    // Limitarea valorii min_y/max_y in intervalul [0, MAX_Y]
    assign min_y = (min_y_raw < 0) ? 0 : ((min_y_raw > MAX_Y) ? MAX_Y : min_y_raw);
    assign max_y = (max_y_raw < 0) ? 0 : ((max_y_raw > MAX_Y) ? MAX_Y : max_y_raw);

endmodule // bounding_box