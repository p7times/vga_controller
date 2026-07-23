//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : rasterizer
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//------------------------------------------------------------------------------
// Descriere : Rasterizor 2D de triunghiuri bazat pe ecuații de margine 
//             (Pineda Algorithm). Parcurge un Bounding Box definit de varfuri, 
//             evalueaza apartenenta fiecarui pixel si trimite datele catre 
//             Framebuffer cu suport pentru flow-control (fb_busy).
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module rasterizer #(
    parameter SCREEN_W = 640,
    parameter SCREEN_H = 480,
    parameter COORD_W  = $clog2(SCREEN_W) + 1    // Lățimea coordonatelor cu semn (bit de semn adăugat)
)(
    input                       clk,            // Semnal de ceas principal
    input                       rst_n,          // Reset asincron (activ pe 0)
    input                       start,          // Semnal de pornire a rasterizării

    // Coordonatele celor 3 vârfuri ale triunghiului
    input signed [COORD_W-1:0]  x0, y0,
    input signed [COORD_W-1:0]  x1, y1,
    input signed [COORD_W-1:0]  x2, y2,

    // Interfața de control direct către Framebuffer (interfață tip RAM/SRAM)
    output reg  [COORD_W-1:0]   fb_x,           // Coordonata X trimisă la Framebuffer
    output reg  [COORD_W-1:0]   fb_y,           // Coordonata Y trimisă la Framebuffer
    output reg                  fb_cs,          // Chip Select pentru Framebuffer (1 = activ)
    output reg                  fb_wr,          // Write Enable pentru Framebuffer (1 = scriere)
    input                       fb_busy,        // Semnal de la Framebuffer: 1 = ocupat (așteptare)

    output reg                  done            // Semnal de finalizare a triunghiului curent
);

    // Dimensiuni de biți pentru diferențe și ecuațiile de margine (previn overflow-ul)
    localparam DIFF_BITS = COORD_W + 1;
    localparam E_BITS    = 2 * DIFF_BITS + 1;

    // Definiția stărilor automatului FSM
    localparam IDLE        = 3'b000,            // Stare de repaus, așteaptă `start`
               WAIT_CORNER = 3'b001,            // Așteaptă calculele inițiale ale ecuațiilor (setup)
               EVAL_PIXEL  = 3'b010,            // Evaluează dacă pixelul curent e în triunghi
               DRAW_WAIT   = 3'b011,            // Așteaptă eliberarea Framebuffer-ului (!fb_busy)
               ADVANCE     = 3'b100,            // Calculează coordonatele următorului pixel (X/Y)
               FINISHED    = 3'b101;            // Semnalează terminarea desenării

    reg [2:0] state, next_state;

    // -------------------------------------------------------------------------
    // 1. Instanțiere Bounding Box (Află limitele min/max în care este înscris triunghiul)
    // -------------------------------------------------------------------------
    wire [COORD_W-1:0] min_x, max_x, min_y, max_y;

    bounding_box #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H)
    ) bbox_inst (
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .min_x(min_x), .max_x(max_x),
        .min_y(min_y), .max_y(max_y)
    );

    // -------------------------------------------------------------------------
    // 2. Instanțiere calc_corner (Calcularea coeficienților inițiali la colțul min_x, min_y)
    // -------------------------------------------------------------------------
    wire signed [E_BITS-1:0]    E0_init, E1_init, E2_init;
    wire signed [DIFF_BITS-1:0] A0, A1, A2; // Pante orizontale (incX)
    wire signed [DIFF_BITS-1:0] B0, B1, B2; // Pante verticale (incY)
    wire                        corner_valid;

    calc_corner #(
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H)
    ) setup_unit (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .px(min_x), .py(min_y),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .E0_out(E0_init), .E1_out(E1_init), .E2_out(E2_init),
        .A0_out(A0), .A1_out(A1), .A2_out(A2),
        .B0_out(B0), .B1_out(B1), .B2_out(B2),
        .valid(corner_valid),
        .dbg_state()            
    );

    // Registre interne pentru urmărirea incrementală a ecuațiilor
    reg signed [E_BITS-1:0]  E0_cur, E1_cur, E2_cur; // Valori pentru pixelul curent
    reg signed [E_BITS-1:0]  E0_row, E1_row, E2_row; // Valori salvate pentru începutul rândului curent
    reg signed [COORD_W-1:0] cur_x, cur_y;          // Poziția X, Y curentă
    reg signed [COORD_W-1:0] reg_min_x, reg_max_x, reg_max_y; // Salvare limite Bounding Box

    // Test de apartenență: Pixelul e în interior dacă toate funcțiile de linie au același semn
    wire pixel_inside = ((E0_cur >= 0 && E1_cur >= 0 && E2_cur >= 0) ||
                         (E0_cur <= 0 && E1_cur <= 0 && E2_cur <= 0));

    // -------------------------------------------------------------------------
    // FSM - Tranziții între stări (Combinațional)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else        state <= next_state;
    end

    always @(*) begin
        case (state)
            IDLE:        next_state = start ? WAIT_CORNER : IDLE;
            WAIT_CORNER: next_state = corner_valid ? EVAL_PIXEL : WAIT_CORNER;
            EVAL_PIXEL:  next_state = pixel_inside ? DRAW_WAIT : ADVANCE; // Dacă e pixel valid îl desenăm, altfel trecem peste
            DRAW_WAIT:   next_state = !fb_busy ? ADVANCE : DRAW_WAIT;     // Așteaptă eliberarea Framebuffer-ului
            ADVANCE:     next_state = ((cur_x == reg_max_x) && (cur_y == reg_max_y)) ? FINISHED : EVAL_PIXEL;
            FINISHED:    next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    // -------------------------------------------------------------------------
    // FSM - Execution & Datapath (Secvențial)
    // -------------------------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done   <= 1'b0;
            cur_x  <= 0;
            cur_y  <= 0;

            fb_x   <= 0; fb_y <= 0;
            fb_cs  <= 1'b0; fb_wr <= 1'b0;

            E0_cur <= 0; E1_cur <= 0; E2_cur <= 0;
            E0_row <= 0; E1_row <= 0; E2_row <= 0;

            reg_min_x <= 0;
            reg_max_x <= 0;
            reg_max_y <= 0;
        end else begin
            // Implicit, semnalele de scriere sunt dezactivate (impulsuri de 1 ciclu)
            done  <= 1'b0;
            fb_cs <= 1'b0;
            fb_wr <= 1'b0;

            case (state)

                IDLE: begin
                    // Repaus
                end

                WAIT_CORNER: begin
                    // Când datele din `calc_corner` sunt gata, inițializăm registrele de parcurgere
                    if (corner_valid) begin
                        E0_cur <= E0_init; E1_cur <= E1_init; E2_cur <= E2_init;
                        E0_row <= E0_init; E1_row <= E1_init; E2_row <= E2_init;

                        cur_x     <= min_x;
                        cur_y     <= min_y;
                        reg_min_x <= min_x;
                        reg_max_x <= max_x;
                        reg_max_y <= max_y;
                    end
                end

                EVAL_PIXEL: begin
                    // Dacă pixelul curent este în interiorul triunghiului, trimitem comanda la Framebuffer
                    if (pixel_inside) begin
                        fb_x  <= cur_x[COORD_W-1:0];
                        fb_y  <= cur_y[COORD_W-1:0];
                        fb_cs <= 1'b1;
                        fb_wr <= 1'b1;
                    end
                end

                DRAW_WAIT: begin
                    // Stare de pauză: fb_cs/fb_wr au fost dezactivate, așteptăm ca fb_busy să devină 0
                end

                ADVANCE: begin
                    // Deplasare la următorul pixel din Bounding Box
                    if (cur_x < reg_max_x) begin
                        // Mutare la dreapta pe orizontală (+1 pe X)
                        cur_x  <= cur_x + 1;
                        E0_cur <= E0_cur + A0;
                        E1_cur <= E1_cur + A1;
                        E2_cur <= E2_cur + A2;
                    end else if (cur_y < reg_max_y) begin
                        // Sfârșit de rând: revenim la min_x și coborâm un rând jos (+1 pe Y)
                        cur_x  <= reg_min_x;
                        cur_y  <= cur_y + 1;

                        // Actualizăm valoarea de bază pentru noul rând
                        E0_row <= E0_row - B0;
                        E1_row <= E1_row - B1;
                        E2_row <= E2_row - B2;

                        // Setăm valoarea curentă pentru primul pixel din noul rând
                        E0_cur <= E0_row - B0;
                        E1_cur <= E1_row - B1;
                        E2_cur <= E2_row - B2;
                    end
                end

                FINISHED: begin
                    done <= 1'b1; // Semnalizăm terminarea rasterizării
                end

            endcase
        end
    end

endmodule // rasterizer