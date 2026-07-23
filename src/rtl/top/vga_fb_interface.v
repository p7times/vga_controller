//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : vga_fb_interface
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//------------------------------------------------------------------------------
// Descriere : Acest modul realizează interfața dintre framebuffer (rezoluție
//             logică 320x240) și controllerul de timing VGA (rezoluție fizică
//             640x480). Realizează o scalare 2x2 prin shiftare și compensează
//             latența de citire a memoriei Block RAM (BRAM).
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module vga_fb_interface #(
    parameter COLOR_BITS    = 4,                                  // Numărul de biți per canal de culoare
    parameter H_RES_LOGIC   = 320,                                // Rezoluția orizontală a bufferului
    parameter V_RES_LOGIC   = 240,                                // Rezoluția verticală a bufferului
    
    parameter H_RES         = 640,                                // Rezoluția orizontală fizică VGA
    parameter V_RES         = 480,                                // Rezoluția verticală fizică VGA
    parameter FB_WORD_ADDR  = $clog2(H_RES_LOGIC * V_RES_LOGIC),  // Dimensiunea adresei liniare BRAM
    
    parameter SCALE_SHIFT_X = $clog2(H_RES / H_RES_LOGIC),        // Factorul de scalare X (ex: 640/320 = 2 -> 1 bit shift)
    parameter SCALE_SHIFT_Y = $clog2(V_RES / V_RES_LOGIC)         // Factorul de scalare Y (ex: 480/240 = 2 -> 1 bit shift)
)(
    input  wire                         pixel_clk,       // Ceasul de pixel VGA (~25.175 MHz)
    input  wire                         rst_n,           // Reset general (activ în 0)
    
    // Semnale de sincronizare și coordonate de la driverul VGA
    input  wire                         hsync_i,         // Sincronizare orizontală de la controller
    input  wire                         vsync_i,         // Sincronizare verticală de la controller
    input  wire                         vde_i,           // Video Display Enable (1 când pixelul e pe ecran)
    input  wire [11:0]                  pixel_x,         // Coordonata X fizică curentă (0..639)
    input  wire [11:0]                  pixel_y,         // Coordonata Y fizică curentă (0..479)
    
    // Interfața cu Framebuffer-ul BRAM
    input  wire [COLOR_BITS-1:0]        fb_video_data,   // Datele citite din BRAM (culoarea pixelului logic)
    output wire [FB_WORD_ADDR-1:0]      fb_video_addr,   // Adresa trimisă către BRAM pentru citire
    
    // Semnal intern de control
    output reg                          ready_internal,  // Puls generat la ultimul pixel activ al cadrului
    
    // Semnale de ieșire către pinii fizici ai plăcii FPGA
    output wire                         hsync_o,         // HSYNC întârziat (sincronizat cu datele din BRAM)
    output wire                         vsync_o,         // VSYNC întârziat (sincronizat cu datele din BRAM)
    output wire [3:0]                   vga_red,         // Canal Roșu către DAC-ul rezistiv
    output wire [3:0]                   vga_green,       // Canal Verde către DAC-ul rezistiv
    output wire [3:0]                   vga_blue         // Canal Albastru către DAC-ul rezistiv
);

    // 1. Dublare 2x2: Mapează coordonata fizică (ex: 0..639) la coordonata logică (ex: 0..319) prin împărțire la 2 (shiftare)
    wire [$clog2(H_RES_LOGIC)-1:0] pixel_x_logic = pixel_x[11:0] >> SCALE_SHIFT_X;
    wire [$clog2(V_RES_LOGIC)-1:0] pixel_y_logic = pixel_y[11:0] >> SCALE_SHIFT_Y;
    
    // 2. Calculul adresei liniare în framebuffer BRAM: Adresa = Y_logic * Latime + X_logic
    assign fb_video_addr = pixel_y_logic * H_RES_LOGIC + pixel_x_logic;
    
    // 3. Pipeline de întârziere cu 1 ciclu de ceas pentru sincronizare cu latența de citire a BRAM-ului
    reg vde_d, hsync_d, vsync_d;
    always @(posedge pixel_clk) begin
        vde_d   <= vde_i;        // Întârzie vde pentru a se potrivi cu sosirea datelor din memorie
        hsync_d <= hsync_i;      // Întârzie hsync pentru aliniere temporală
        vsync_d <= vsync_i;      // Întârzie vsync pentru aliniere temporală
    end    

    // 4. Detecția ultimului pixel fizic activ din cadru (X = 639, Y = 479)
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n)
            ready_internal <= 0;
        else
            // Generează un puls de un ciclu când s-a parcurs tot ecranul activ
            ready_internal <= (pixel_x == H_RES-1) && (pixel_y == V_RES-1) && vde_i;
    end

    // 5. Atribuire culori pe canale: dacă suntem în regiunea activă (vde_d=1), transmitem datele, altfel blackout (0)
    assign vga_red   = vde_d ? fb_video_data : 4'h0;
    assign vga_green = vde_d ? fb_video_data : 4'h0;
    assign vga_blue  = vde_d ? fb_video_data : 4'h0;

    // Conectarea semnalelor de sincronizare întârziate la ieșiri
    assign hsync_o = hsync_d;
    assign vsync_o = vsync_d;

endmodule // vga_fb_interface