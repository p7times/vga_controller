`timescale 1ns / 1ps

// =============================================================================
// shape_renderer
// -----------------------------------------------------------------------------
// Modul de "desen": primeste coordonatele pixelului curent (h_pos, v_pos)
// si decide ce culoare trebuie afisata in acel punct - fundal, un dreptunghi
// sau un cerc, in functie de parametri.
//
// Nu stie nimic despre timing VGA (hsync/vsync/blanking) - de asta se ocupa
// vga_driver.
// =============================================================================

module shape_renderer #(

    parameter int color_w  = 4,     // biti per canal de culoare
    parameter int h_active = 640,   // latimea zonei vizibile (trebuie sa coincida cu vga_driver)
    parameter int v_active = 480,   // inaltimea zonei vizibile (trebuie sa coincida cu vga_driver)

    // -------------------------------------------------------------------
    // culoare de fundal (folosita acolo unde nu e nicio forma)
    // -------------------------------------------------------------------
    parameter logic [color_w-1:0] bg_red   = '0,
    parameter logic [color_w-1:0] bg_green = '0,
    parameter logic [color_w-1:0] bg_blue  = '0,

    // -------------------------------------------------------------------
    // dreptunghi: colt stanga-sus (rect_x, rect_y), latime rect_w, inaltime rect_h
    // -------------------------------------------------------------------
    parameter bit rect_enable = 1'b1,
    parameter int rect_x = 100,
    parameter int rect_y = 100,
    parameter int rect_w = 20,
    parameter int rect_h = 150,
    parameter logic [color_w-1:0] rect_red   = 4'h5,
    parameter logic [color_w-1:0] rect_green = 4'h5,
    parameter logic [color_w-1:0] rect_blue  = 4'h5,

    // -------------------------------------------------------------------
    // cerc: centru (circle_cx, circle_cy), raza circle_r
    // -------------------------------------------------------------------
    parameter bit circle_enable = 1'b1,
    parameter int circle_cx = 450,
    parameter int circle_cy = 240,
    parameter int circle_r  = 10,
    parameter logic [color_w-1:0] circle_red   = 4'hA,
    parameter logic [color_w-1:0] circle_green = 4'hA,
    parameter logic [color_w-1:0] circle_blue  = 4'hA

)(

    input  logic [$clog2(h_active)-1:0] h_pos,   // coordonata orizontala a pixelului curent (0 .. h_active-1)
    input  logic [$clog2(v_active)-1:0] v_pos,   // coordonata verticala a pixelului curent  (0 .. v_active-1)

    output logic [color_w-1:0] pix_red,
    output logic [color_w-1:0] pix_green,
    output logic [color_w-1:0] pix_blue

);

    // =========================================================================
    // dreptunghi: pixelul e "in interior" daca e in intervalul [x, x+w) x [y, y+h)
    // =========================================================================

    logic in_rect;

    assign in_rect = rect_enable &&
                      (int'(h_pos) >= rect_x) && (int'(h_pos) < rect_x + rect_w) &&
                      (int'(v_pos) >= rect_y) && (int'(v_pos) < rect_y + rect_h);

    // =========================================================================
    // cerc: pixelul e "in interior" daca distanta^2 fata de centru <= raza^2
    // (se compara distanta la patrat ca sa evitam radacina patrata in hardware)
    // =========================================================================

    int dx, dy;
    int dist_sq;
    int radius_sq;

    always_comb begin

        dx        = int'(h_pos) - circle_cx;   // diferenta pe orizontala fata de centru
        dy        = int'(v_pos) - circle_cy;   // diferenta pe verticala fata de centru
        dist_sq   = dx*dx + dy*dy;             // distanta la patrat (evitam sqrt)
        radius_sq = circle_r * circle_r;       // raza la patrat, pentru comparatie directa

    end

    logic in_circle;

    assign in_circle = circle_enable && (dist_sq <= radius_sq);

    // =========================================================================
    // combinare: prioritate cerc > dreptunghi > fundal
    // (daca cele doua forme se suprapun, cercul se vede "deasupra")
    // =========================================================================

    always_comb begin

        if (in_circle) begin

            pix_red   = circle_red;
            pix_green = circle_green;
            pix_blue  = circle_blue;

        end else if (in_rect) begin

            pix_red   = rect_red;
            pix_green = rect_green;
            pix_blue  = rect_blue;

        end else begin

            pix_red   = bg_red;
            pix_green = bg_green;
            pix_blue  = bg_blue;

        end

    end

endmodule
