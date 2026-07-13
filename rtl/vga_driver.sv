`timescale 1ns / 1ps

module vga_driver #(

    parameter int color_w = 4                                   // Numărul de biți pentru canalele R,G,B

)(

    input  logic                pix_clk,                        // Ceasul sistemului (25 MHz pentru 640x480)
    input  logic                rst_n,                          // Reset asincron, activ în 0

    // --- INTERFAȚA CU RENDERER-UL ---
    output logic [9:0]          h_pos,                          // Ieșire: coordonata X curentă către renderer
    output logic [9:0]          v_pos,                          // Ieșire: coordonata Y curentă către renderer
    input  logic [color_w-1:0]  pix_red,                        // Intrare: culoarea roșie calculată de renderer
    input  logic [color_w-1:0]  pix_green,                      // Intrare: culoarea verde calculată de renderer
    input  logic [color_w-1:0]  pix_blue,                       // Intrare: culoarea albastră calculată de renderer

    // --- INTERFAȚA FIZICĂ VGA ---
    output logic                hsync,                          // Semnal de sincronizare pentru desenare pe orizontală
    output logic                vsync,                          // Semnal de sincronizare pentru desenare pe verticală

    output logic [color_w-1:0]  vga_red,                        // Semnal de ieșire fizic: canalul roșu
    output logic [color_w-1:0]  vga_green,                      // Semnal de ieșire fizic: canalul verde
    output logic [color_w-1:0]  vga_blue                        // Semnal de ieșire fizic: canalul albastru

);

    // =========================================================================
    // PARAMETRI DE TIMING VGA PENTRU SETARE REZOLUȚIE 640x480 @ 60Hz
    // =========================================================================

    localparam int h_bp     = 48;                               // Back porch orizontal
    localparam int h_active = 640;                              // Nr de pixeli vizibili pe o linie
    localparam int h_fp     = 16;                               // Front porch orizontal
    localparam int h_sync   = 96;                               // Durata pulsului de sincronizare orizontală    

    localparam int v_bp     = 33;                               // Back porch vertical
    localparam int v_active = 480;                              // Nr de linii vizibile într-un cadru
    localparam int v_fp     = 10;                               // Front porch vertical
    localparam int v_sync   = 2;                                // Durata pulsului de sincronizare verticală
    
    localparam int h_total  = h_active + h_fp + h_sync + h_bp;  // Perioada orizontală totală
    localparam int v_total  = v_active + v_fp + v_sync + v_bp;  // Perioada verticală totală
 
    localparam logic h_pol = 1'b0;                              // Polaritatea hsync (negativă)
    localparam logic v_pol = 1'b0;                              // Polaritatea vsync (negativă)


    // =========================================================================
    // NUMĂRĂTORI POZIȚIE PIXEL / LINIE
    // =========================================================================

    logic [$clog2(h_total)-1:0] h_cnt;                          
    logic [$clog2(v_total)-1:0] v_cnt;                          
 
    always_ff @(posedge pix_clk or negedge rst_n) begin         
 
        if (!rst_n) begin                                   
            h_cnt <= '0;     
            v_cnt <= '0;       
        end else begin           
            if (h_cnt == h_total - 1) begin                     
                h_cnt <= '0;                                    
                if (v_cnt == v_total - 1)                       
                    v_cnt <= '0;                                
                else
                    v_cnt <= v_cnt + 1'b1;                      
            end else begin
                h_cnt <= h_cnt + 1'b1;                          
            end
        end
 
    end

    // =========================================================================
    // CONECTARE COORDONATE CĂTRE EXTERIOR (RENDERER)
    // =========================================================================
    
    // Convertim contoarele interne la 10 biți pentru a acoperi maxim 1023
    assign h_pos = 10'(h_cnt);
    assign v_pos = 10'(v_cnt);

    // =========================================================================
    // DECODARE ZONE: ACTIV, H-SYNC, V-SYNC
    // =========================================================================

    logic h_sync_area;                                          
    logic v_sync_area;                                          
    logic active;                                               

    assign h_sync_area = (h_cnt >= h_active + h_fp) && (h_cnt <  h_active + h_fp + h_sync);
    assign v_sync_area = (v_cnt >= v_active + v_fp) && (v_cnt <  v_active + v_fp + v_sync);
    assign active      = (h_cnt < h_active) && (v_cnt < v_active);

    // =========================================================================
    // SINCRONIZĂRI
    // =========================================================================

    assign hsync = h_sync_area ? h_pol : ~h_pol;
    assign vsync = v_sync_area ? v_pol : ~v_pol;
    
    // =========================================================================
    // CULOARE FIZICĂ: folosește culorile calculate de renderer, blanking în rest
    // =========================================================================
    
    assign vga_red   = (rst_n && active) ? pix_red   : '0;
    assign vga_green = (rst_n && active) ? pix_green : '0;
    assign vga_blue  = (rst_n && active) ? pix_blue  : '0;
    
endmodule