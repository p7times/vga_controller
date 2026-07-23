//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : shape_renderer
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//------------------------------------------------------------------------------
// Descriere : Modul top-level pentru randarea formelor grafice (triunghiuri).
//             Integrează modulul de rasterizare (`rasterizer`) cu un modul de 
//             memorie Framebuffer Dublu (`framebuffer_dbl`). Permite desene 
//             fără efect de flicker (flicker-free rendering) prin comutarea 
//             bufferelor (swap) și curățarea automată (clear) la fiecare cadru.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module shape_renderer #(
    parameter H_ACTIVE   = 320,                                         // Rezoluția LOGICĂ pe orizontală a framebuffer-ului
    parameter V_ACTIVE   = 240,                                         // Rezoluția LOGICĂ pe verticală a framebuffer-ului
    parameter COORD_W     = $clog2(H_ACTIVE)+1,                         // Lățimea în biți a coordonatelor (cu bit de semn)
    parameter COLOR_BITS  = 4                                           // Adâncimea de culoare (ex: 4 biți per pixel)
)(
    input  wire                                     clk,                // Semnalul de ceas sistem
    input  wire                                     rst_n,              // Reset asincron (activ pe 0)

    // Interfața de control pentru randarea unui triunghi
    input  wire                                     start,              // Puls de start pentru randare triunghi
    input  wire signed [COORD_W-1:0]                x0, y0,             // Coordonatele primului vârf
    input  wire signed [COORD_W-1:0]                x1, y1,             // Coordonatele celui de-al doilea vârf
    input  wire signed [COORD_W-1:0]                x2, y2,             // Coordonatele celui de-al treilea vârf
    input  wire [COLOR_BITS-1:0]                    color,              // Culoarea aplicată triunghiului curent
    output wire                                     done,               // Semnalizează că rasterizorul a terminat triunghiul

    // Control sincronizare cadru video
    input  wire                                     frame_end_pulse,    // Puls extern de 1 ciclu la final de cadru VGA

    // Interfață de citire continuă pentru afișarea pe ecran (VGA / Display Controller)
    input  wire [$clog2(H_ACTIVE*V_ACTIVE)-1:0]     rd_address,         // Adresa pixelului pe rezoluția logică
    output wire [COLOR_BITS-1:0]                    rd_dataOut          // Valoarea culorii pixelului citit
);

    // -------------------------------------------------------------------
    // Semnale interne de interconectare: Rasterizer -> Framebuffer
    // -------------------------------------------------------------------
    wire [COORD_W-1:0]  fb_x, fb_y;  // Coordonatele pixelului curent generat de rasterizor
    wire                fb_cs;        // Chip select pentru scriere în framebuffer (1 = activ)
    wire                fb_wr;        // Write enable pentru scriere în framebuffer (1 = scriere)
    wire                fb_busy;      // Semnal de ocupat de la framebuffer (blochează rasterizorul)

    // -------------------------------------------------------------------
    // Instanțiere Rasterizor de triunghiuri
    // -------------------------------------------------------------------
    rasterizer #(
        .SCREEN_W(H_ACTIVE),
        .SCREEN_H(V_ACTIVE)
    ) u_rasterizer (
        .clk(clk), 
        .rst_n(rst_n),
        .start(start),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .fb_x(fb_x), .fb_y(fb_y),
        .fb_cs(fb_cs), .fb_wr(fb_wr),
        .fb_busy(fb_busy),
        .done(done)
    );

    // -------------------------------------------------------------------
    // Generare secvențială pentru semnalele `swap` și `clear`
    // -------------------------------------------------------------------
    // `frame_end_pulse` declanșează mai întâi schimbarea bufferelor (swap),
    // iar în ciclul următor declanșează curățarea (clear) noului buffer din spate.
    reg swap_pulse, clear_pulse;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            swap_pulse  <= 1'b0;
            clear_pulse <= 1'b0;
        end else begin
            swap_pulse  <= frame_end_pulse; // Puls de swap în starea curentă
            clear_pulse <= swap_pulse;      // Puls de clear întârziat cu un ciclu de ceas
        end
    end

    // -------------------------------------------------------------------
    // Instanțiere Framebuffer Dublu (Double Buffer)
    // -------------------------------------------------------------------
    framebuffer_dbl #(
        .H_RES(H_ACTIVE),
        .V_RES(V_ACTIVE),
        .COLOR_BITS(COLOR_BITS)
    ) u_fb (
        .clk(clk), 
        .rst_n(rst_n),

        // Portul de scriere dinspre Rasterizor (desenează în buffer-ul din spate)
        .cs(fb_cs), 
        .wr(fb_wr), 
        .clear(clear_pulse),
        .x_in(fb_x[$clog2(H_ACTIVE)-1:0]),
        .y_in(fb_y[$clog2(V_ACTIVE)-1:0]),
        .pixel_in(color),
        .busy(fb_busy),

        // Semnal de inversare a bufferelor (Front/Back)
        .swap(swap_pulse),

        // Portul de citire către interfata VGA (citește din buffer-ul din față)
        .rd_address(rd_address),
        .rd_dataOut(rd_dataOut),

        // Semnale de debug neconectate
        .dbg_fb_i_state(), 
        .dbg_fb_ii_state(), 
        .dbg_disp_buf()
    );

endmodule // shape_renderer