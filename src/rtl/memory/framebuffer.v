//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : framebuffer
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Modul framebuffer implementat folosind Block RAM (BRAM)
//              inferat automat de sintetizator.
//
//              Memoria stocheaza un framebuffer 4-bit color,
//              unde fiecare 4 biți reprezinta un pixel.
//
//              Functionalitati:
//                  - scriere individuala de pixeli
//                  - citire continua pentru HDMI/VGA controller
//                  - stergere completa a framebuffer-ului
//
//              Arhitectura:
//                  - Dual-port BRAM
//                      * Port A -> citire
//                      * Port B -> scriere
//---------------------------------------------------------------

`timescale 1ns / 1ps

module framebuffer #(
    parameter H_RES         = 320,                                  // Rezolutie orizontala in pixeli
    parameter V_RES         = 240,                                  // Rezolutie verticala in pixeli
    parameter COLOR_BITS    = 4,                                    // Numar de biti per cuvant BRAM (4 biti = 1 pixel, 16 nivele de gri)
    parameter TOTAL_WORDS   = H_RES * V_RES,                        // Numarul total de cuvinte in memorie
    parameter FB_ADDR_WIDTH = $clog2(TOTAL_WORDS)                   // Numarul minim de biti necesari pentru adresarea cuvintelor
)(
    input                           clk,                            // Semnal de ceas
    input                           rst_n,                          // Reset asincron (activ in 0)
    input                           cs,                             // Chip select
    input                           wr,                             // Scriere/citire
    input                           clear,                          // Comanda pentru stergerea framebuffer-ului

    // Interfata scriere pixel individual (de la BU)
    input  [$clog2(H_RES)-1:0]      x_in,                           // 0..319
    input  [$clog2(V_RES)-1:0]      y_in,                           // 0..239
    input  [COLOR_BITS-1:0]         pixel_in,                       // Valoare pixel: 0 -> negru, F -> alb

    // Interfata citire
    input      [FB_ADDR_WIDTH-1:0]  rd_address,                     // Adresa de citire pentru portul A
    output reg [COLOR_BITS-1:0]     rd_dataOut,                     // Registru date citite din BRAM

    // Semnale status/debug
    output                          busy,                           // Semnal care indica starea de stergere in desfasurare
    output     [FB_ADDR_WIDTH-1:0]  dbg_clear_addr,                 // Debug FSM clear
    output                          dbg_state                       // Debug stare FSM
);
    
    // ------------------------
    // Definitie stari FSM
    // ------------------------

    localparam IDLE     = 1'd0,   // Asteapta semnalul de start
               CLEARING = 1'd1;   // Sterge datele din memorie

    reg state, next_state;                                          // Registru de stare si fir pentru starea urmatoare
    assign dbg_state = state;                                       // Expunerea starii FSM pe iesirea de depanare


    // ------------------------------------------------
    // Memorie framebuffer: 1 cuvant = 1 pixel (COLOR_BITS biti)
    // ------------------------------------------------
    
    reg [COLOR_BITS-1:0] mem [0:TOTAL_WORDS-1];                    // Declararea matricei de memorie BRAM (Array de registre)


    //-----------------------------------------------------------
    // CALCUL ADRESA PIXEL
    //-----------------------------------------------------------
    // pixel_index = y * H_RES + x
    //-----------------------------------------------------------

    wire [FB_ADDR_WIDTH-1:0] pixel_addr;                            // Adresa cuvantului BRAM
    wire in_bounds    = (x_in < H_RES) && (y_in < V_RES);           // Protectie coordonate invalide (verifica daca X si Y sunt pe ecran)
    assign pixel_addr = y_in * H_RES + x_in;                        // Formularea adresei liniare din coordonatele 2D (Y * H_RES + X)


    // ------------------------------------------------
    // Registre interne FSM si semnale Clear
    // ------------------------------------------------

    reg [FB_ADDR_WIDTH-1:0] clear_addr;                             // Contor adresa curenta pentru operatia de stergere secventiala
    reg clear_d;                                                    // Delay pentru detectie front pozitiv clear
    wire clear_start = clear & ~clear_d;                            // Puls un singur ciclu la activarea clear (edge detection)
      
    assign busy = (state == CLEARING);                              // Semnalul busy este activ doar cat timp FSM este in starea CLEARING
    assign dbg_clear_addr = clear_addr;                             // Expunerea adresei curente de stergere la ieșirea de depanare


    // ------------------------
    // Logica FSM - Calea de control
    // ------------------------

    always @(posedge clk or negedge rst_n) begin                    // Registru de stare sincronizat pe ceas cu reset asincron
        if (!rst_n) state <= IDLE;                                  // Resetare stare FSM in IDLE
        else        state <= next_state;                            // Tranzitie la starea urmatoare
    end

    always @(*) begin                                               // Logica combinationala pentru determinarea starii urmatoare
        case (state)
            IDLE:       next_state = clear_start ? CLEARING : IDLE;   // Asteptare comenzi: trece in CLEARING la un impuls clear_start
            CLEARING:   next_state = (clear_addr == TOTAL_WORDS - 1) ? IDLE : CLEARING;           // Stergere secventiala a framebuffer-ului pana la ultima adresa
            default:    next_state = IDLE;                           // Tratare caz implicit (siguranta FSM)
        endcase
    end


    // ------------------------------------------------
    // Logica FSM - Calea de date
    // ------------------------------------------------
    always @(posedge clk or negedge rst_n) begin                    // Proces secvential pentru calea de date si contoare

        if (!rst_n) begin                                           // Resetare registre la semnalul rst_n
            clear_d    <= 1'b0;                                     // Resetare registru intarziere clear
            clear_addr <= {FB_ADDR_WIDTH{1'b0}};                    // Resetare contor adresa de stergere
        end
        else begin
            clear_d <= clear;   // memoram clear pentru edge detect // Memorare stare anterioara a semnalului clear
            case (state)
                IDLE: begin                                         // In starea IDLE
                    if (clear_start) clear_addr <= {FB_ADDR_WIDTH{1'b0}}; // Reinitializare contor adresa de stergere la 0 la pornire clear
                end

                // Incrementare adresa clear                
                CLEARING: begin                                     // In starea CLEARING
                    if (clear_addr != TOTAL_WORDS - 1)              // Daca nu s-a atins ultima adresa din memorie
                        clear_addr <= clear_addr + 1'b1;            // Incrementare adresa de stergere cu 1
                end 

            endcase
        end
    end


    // ------------------------------------------------
    // Port A (Citire)
    // ------------------------------------------------

    always @(posedge clk) begin                                     // Citire sincrona pe Portul A (pentru afisarea pe ecran)
        rd_dataOut <= mem[rd_address];                              // Incarcare date din memorie in registrul de iesire rd_dataOut
    end


    // ------------------------------------------------
    // Port B (Acces FSM pentru Scriere/Stergere)
    // ------------------------------------------------

    wire                        port_b_we;                          // Semnal de permisiune scriere pentru Portul B
    wire [FB_ADDR_WIDTH-1:0]    port_b_addr;                        // Adresa conectata la Portul B
    wire [COLOR_BITS-1:0]        port_b_data_in;                     // Datele de intrare de scris prin Portul B

    // Conditia de scriere a unui pixel valid (prioritate scazuta fata de Clear)
    wire write_pixel_req  = (state == IDLE) && !clear_start && cs && wr && in_bounds; // Cerere valida de scriere a unui pixel
    
    assign port_b_we      = (state == CLEARING) || write_pixel_req;                 // Write Enable: activ fie la stergere, fie la scriere pixel valid
    assign port_b_addr    = (state == CLEARING) ? clear_addr : pixel_addr;          // Selectie adresa: adresa de stergere sau adresa pixelului calculat
    assign port_b_data_in = (state == CLEARING) ? {COLOR_BITS{1'b0}} : pixel_in;   // Date scrise in BRAM: 0 la stergere, sau culoarea pixel_in

    // Inferare Block RAM dual-port:
    always @(posedge clk) begin                                     // Proces sincron pentru scrierea fizica pe Portul B in Block RAM
        if (port_b_we) begin                                        // Daca scrierea este activata
            mem[port_b_addr] <= port_b_data_in;     // Scriere      // Salvare date la adresa corespunzatoare in memorie
        end
    end

endmodule // framebuffer
