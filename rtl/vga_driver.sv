`timescale 1ns / 1ps

module vga_driver #(

    parameter int color_w                       = 4,            // Numărul de biți pentru canalele R,G,B (determina nr max de culori reprezentabile)

    parameter logic [color_w-1:0] image_red     = '1,           // Valoarea pentru canalul roșu
    parameter logic [color_w-1:0] image_green   = '0,           // Valoarea pentru canalul verde
    parameter logic [color_w-1:0] image_blue    = '0            // Valoarea pentru canalul albastru

)(

    input  logic                pix_clk,                        // Ceasul sistemului
    input  logic                rst_n,                          // Reset asincron, activ în 0

    output logic                hsync,                          // Semnal de sincronizare pentru desenare pe orizontală
    output logic                vsync,                          // Semnal de sincronizare pentru desenare pe verticală

    output logic [color_w-1:0]  vga_red,                        // Semnal de ieșire: canalul roșu
    output logic [color_w-1:0]  vga_green,                      // Semnal de ieșire: canalul verde
    output logic [color_w-1:0]  vga_blue                        // Semnal de ieșire: canalul albastru

);

    // =========================================================================
    // PARAMETRI DE TIMING VGA PENTRU REZOLUȚIA 640x480
    // =========================================================================

    localparam int h_active = 640;                              // Nr de pixeli vizibili pe o linie (ce se vede efectiv pe ecran, pe orizontală)
    localparam int h_fp     = 16;                               // Front porch orizontal: pauza dintre sfârșitul liniei vizibile și începutul pulsului de h-sync
    localparam int h_sync   = 96;                               // Durata (în pixeli) cât h-sync stă în starea activă (pulsul propriu-zis de sincronizare orizontală) 
    localparam int h_bp     = 48;                               // Back porch orizontal: pauza dintre sfârșitul pulsului de h-sync și începutul liniei vizibile următoare
    localparam int h_total  = h_active + h_fp + h_sync + h_bp;  // Nr total de pixeli pe o linie completă (vizibil + toate pauzele), adică perioada orizontală

    localparam int v_active = 480;                              // Nr de linii vizibile într-un cadru (ce se vede efectiv pe ecran, pe verticală)
    localparam int v_fp     = 10;                               // Front porch vertical: pauza (în linii) dintre ultima linie vizibilă și pulsul de v-sync
    localparam int v_sync   = 2;                                // Durata (în linii) cât v-sync stă în starea activă (pulsul de sincronizare verticală)
    localparam int v_bp     = 33;                               // Back porch vertical: pauza (în linii) dintre pulsul de v-sync și prima linie vizibilă a cadrului următor
    localparam int v_total  = v_active + v_fp + v_sync + v_bp;  // Nr total de linii dintr-un cadru complet (vizibil + toate pauzele), adică perioada verticală
 
    localparam logic h_pol = 1'b0;                              // Polaritatea hsync: 0 = sincronizare activă pe nivel logic 0 (negativă), standard pentru 640x480@60Hz
    localparam logic v_pol = 1'b0;                              // Polaritatea vsync: 0 = sincronizare activă pe nivel logic 0 (negativă), standard pentru 640x480@60Hz


    // =========================================================================
    // NUMĂRĂTORI POZIȚIE PIXEL / LINIE
    // =========================================================================

    logic [$clog2(h_total)-1:0] h_cnt;                          // Numărătorul de poziție pe orizontală (indexul pixelului curent în cadrul liniei, 0 .. h_total-1)
    logic [$clog2(v_total)-1:0] v_cnt;                          // Numărătorul de poziție pe verticală (indexul liniei curente în cadrul întregului cadru, 0 .. v_total-1)
 
    always_ff @(posedge pix_clk or negedge rst_n) begin         // Bloc secvențial: se declanșează fie la fiecare front crescător de ceas, fie imediat (asincron) la căderea lui rst_n
 
        if (!rst_n) begin                                   
        
            // Cât timp reset-ul e activ (rst_n = 0), numărătoarele orizontale și verticale se pun pe 0
            h_cnt <= '0;     
            v_cnt <= '0;       
 
        end else begin           
        
            // În funcționare normală:
            if (h_cnt == h_total - 1) begin                     // Dacă am ajuns la ultimul pixel din linia curentă...
 
                h_cnt <= '0;                                    // ...reîncepem linia de la pixelul 0
 
                if (v_cnt == v_total - 1)                       // Dacă, în plus, era și ultima linie din cadru...
                    v_cnt <= '0;                                // ...reîncepem cadrul de la linia 0 (s-a terminat un cadru complet)
                else
                    v_cnt <= v_cnt + 1'b1;                      // ...altfel trecem pur și simplu la linia următoare
 
            end else
                h_cnt <= h_cnt + 1'b1;                          // Dacă nu suntem la finalul liniei, trecem la pixelul următor de pe linia curentă
 
        end
 
    end


    // =========================================================================
    // DECODARE ZONE: ACTIV, H-SYNC, V-SYNC
    // =========================================================================

    logic h_sync_area;                                          // 1 cât timp pixelul curent se află în fereastra de puls hsync (pe orizontală)
    logic v_sync_area;                                          // 1 cât timp linia curentă se află în fereastra de puls vsync (pe verticală)
    logic active;                                               // 1 cât timp poziția curentă (h_cnt, v_cnt) e în zona vizibilă a ecranului

    // h_sync_area e 1 exact după zona vizibilă și front porch, cât durează pulsul de sincronizare orizontală
    assign h_sync_area = (h_cnt >= h_active + h_fp) && (h_cnt <  h_active + h_fp + h_sync);
    
    // v_sync_area e 1 exact după zona vizibilă și front porch, cât durează pulsul de sincronizare verticală
    assign v_sync_area = (v_cnt >= v_active + v_fp) && (v_cnt <  v_active + v_fp + v_sync);

    // active e 1 doar dacă atât poziția orizontală, cât și cea verticală, sunt în interiorul zonei vizibile (640x480) - aici se desenează efectiv imaginea
    assign active = (h_cnt < h_active) && (v_cnt < v_active);


    // =========================================================================
    // SINCRONIZĂRI
    // =========================================================================

    // Cât timp suntem în fereastra de sync orizontal, h-sync ia valoarea polarității active (h_pol); altfel ia valoarea opusă (starea de repaus/inactivă)
    assign hsync = h_sync_area ? h_pol : ~h_pol;
    
    // Cât timp suntem în fereastra de sync vertical, v-sync ia valoarea polarității active (v_pol); altfel ia valoarea opusă (starea de repaus/inactivă)
    assign vsync = v_sync_area ? v_pol : ~v_pol;
    
    
    // =========================================================================
    // CULOARE: doar in zona activa, negru in rest (blanking)
    // =========================================================================
    
    // Canalul roșu iese cu valoarea parametrului image_red DOAR dacă nu suntem în reset ȘI suntem în zona vizibilă; altfel iese 0 (negru, blanking)
    assign vga_red   = (rst_n && active) ? image_red   : '0;
    
    // Canalul verde iese cu valoarea parametrului image_green DOAR dacă nu suntem în reset ȘI suntem în zona vizibilă; altfel iese 0 (negru, blanking)
    assign vga_green = (rst_n && active) ? image_green : '0;
    
    // Canalul albastru iese cu valoarea parametrului image_blue DOAR dacă nu suntem în reset ȘI suntem în zona vizibilă; altfel iese 0 (negru, blanking)
    assign vga_blue  = (rst_n && active) ? image_blue  : '0;
    
    // Condiția "rst_n &&" e obligatorie aici: h_cnt=v_cnt=0 (starea imediat după reset) cade în interiorul zonei active,
    // deci fără acest && am scoate culoarea de test chiar și în timpul reset-ului (bug găsit și corectat anterior)

endmodule