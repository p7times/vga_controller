//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : vga_driver
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//------------------------------------------------------------------------------
// Descriere : Generează semnalele de timing standard VGA 640x480 @ 60Hz.
//             Orchestrează numărătoarele orizontale și verticale, generând 
//             impulsurile HSYNC, VSYNC, VDE și coordonatele (X, Y) curente.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module vga_driver #(   
    parameter COORD_BITS    = 12,     // Numărul de biți alocați pentru coordonate

    // Parametri de timing orizontal (în pixeli) pentru standardul 640x480 @ 60Hz
    parameter H_FP          = 16,     // Horizontal Front Porch
    parameter H_ACTIVE      = 640,    // Zona orizontală activă afișabilă
    parameter H_SYNC        = 96,     // Pulsul HSYNC
    parameter H_BP          = 48,     // Horizontal Back Porch
    
    // Parametri de timing vertical (în linii)
    parameter V_FP          = 10,     // Vertical Front Porch
    parameter V_ACTIVE      = 480,    // Zona verticală activă afișabilă
    parameter V_SYNC        = 2,      // Pulsul VSYNC
    parameter V_BP          = 33      // Vertical Back Porch
)(
    input  wire                      pixel_clk,   // Frecvența de pixel (~25.175 MHz)
    input  wire                      rst_n,       // Reset activ în 0

    output wire                      hsync,       // Semnal de sincronizare orizontală
    output wire                      vsync,       // Semnal de sincronizare verticală
    output wire                      vde,         // Video Display Enable (1 = pixel vizibil pe ecran)
    output wire [COORD_BITS-1:0]     pixel_x,     // Coordonata orizontală curentă
    output wire [COORD_BITS-1:0]     pixel_y      // Coordonata verticală curentă
);

    // Calculul numărului total de pixeli/linii per cadru (inclusiv regiunile de blanking)
    localparam H_TOTAL = H_ACTIVE + H_FP + H_SYNC + H_BP; // Total = 800 pixeli
    localparam V_TOTAL = V_ACTIVE + V_FP + V_SYNC + V_BP; // Total = 525 linii

    // Polaritate negativă a semnalelor de sincronizare conform standardului VGA 640x480
    localparam H_POL = 1'b0;
    localparam V_POL = 1'b0;

    // Registre interne pentru contorizarea poziției fasciculului video
    reg [$clog2(H_TOTAL)-1:0] h_cnt;
    reg [$clog2(V_TOTAL)-1:0] v_cnt;

    // Logica de parcurgere a ecranului linie cu linie (scanline raster)
    always @(posedge pixel_clk or negedge rst_n) begin
        if (!rst_n) begin
            h_cnt <= 0;
            v_cnt <= 0;
        end else begin
            if (h_cnt == H_TOTAL - 1) begin
                h_cnt <= 0;
                if (v_cnt == V_TOTAL - 1)
                    v_cnt <= 0;               // Reset contor vertical la final de cadru
                else
                    v_cnt <= v_cnt + 1'b1;     // Trecere la linia următoare
            end else begin
                h_cnt <= h_cnt + 1'b1;         // Avansare pixel pe linia curentă
            end
        end
    end

    // Determinarea regiunilor de sincronizare și activitate video
    wire h_sync_area = (h_cnt >= H_ACTIVE + H_FP) && (h_cnt < H_ACTIVE + H_FP + H_SYNC);
    wire v_sync_area = (v_cnt >= V_ACTIVE + V_FP) && (v_cnt < V_ACTIVE + V_FP + V_SYNC);
    wire active      = (h_cnt < H_ACTIVE) && (v_cnt < V_ACTIVE);

    // Generare ieșiri de sincronizare conform polarității specificate
    assign hsync = h_sync_area ? H_POL : ~H_POL;
    assign vsync = v_sync_area ? V_POL : ~V_POL;
    assign vde   = active;

    // Maparea contoarelor interne la ieșirile de coordonate (cu extindere pe biți)
    assign pixel_x = {{(COORD_BITS-$clog2(H_TOTAL)){1'b0}}, h_cnt};
    assign pixel_y = {{(COORD_BITS-$clog2(V_TOTAL)){1'b0}}, v_cnt};
    
endmodule // vga_driver
