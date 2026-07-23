//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : calc_corner
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Testeaza daca punctul (px,py) - coltul stanga-sus al bounding
//              box-ului (min_x, min_y) - se afla in interiorul triunghiului definit de
//              varfurile (x0,y0), (x1,y1), (x2,y2).
//
//              Formula folosita (edge function / half-space test), pentru fiecare muchie:
//
//              E(px,py) = (px - xA)*(yB - yA) - (py - yA)*(xB - xA)
//
//              unde (xA,yA)->(xB,yB) sunt, pe rand, cele 3 muchii ale triunghiului:
//                  muchia 0: (x0,y0) -> (x1,y1)
//                  muchia 1: (x1,y1) -> (x2,y2)
//                  muchia 2: (x2,y2) -> (x0,y0)
//
//              Punctul e in interior daca semnul lui E este ACELASI pentru toate cele 3 muchii.
//---------------------------------------------------------------

`timescale 1ns / 1ps

module calc_corner #(
    parameter SCREEN_W   = 640,                                            // Latimea ecranului in pixeli
    parameter SCREEN_H   = 480,                                            // Inaltimea ecranului in pixeli
    parameter COORD_BITS = $clog2(SCREEN_W)+1                              // Numarul de biti necesar pentru coordonate semnate
)(
    input                                   clk,                           // Semnalul de ceas (clock)
    input                                   rst_n,                         // Semnalul de reset asincron, activ pe '0' (active low)
    input                                   start,                         // Semnalul de start pentru initierea calculului

    // Punctul testat (de regula min_x, min_y din bounding_box)
    input signed [COORD_BITS-1:0]           px, py,                        // Coordonatele X si Y ale punctului de referinta (coltul)

    // Cele 3 varfuri ale triunghiului
    input signed [COORD_BITS-1:0]           x0, y0,                        // Coordonatele primului varf (V0)
    input signed [COORD_BITS-1:0]           x1, y1,                        // Coordonatele celui de-al doilea varf (V1)
    input signed [COORD_BITS-1:0]           x2, y2,                        // Coordonatele celui de-al treilea varf (V2)

    // Rezultatele necesare pentru rasterizer incremental
    output reg signed [2*COORD_BITS+2:0]    E0_out, E1_out, E2_out,        // Valorile functiilor de muchie evaluate in punctul (px, py)
    output reg signed [COORD_BITS:0]        A0_out, A1_out, A2_out,        // Coeficientii A (delta Y = yB - yA) pentru pasul pe X
    output reg signed [COORD_BITS:0]        B0_out, B1_out, B2_out,        // Coeficientii B (delta X = xB - xA) pentru pasul pe Y
    output reg                              valid,                         // Impuls de iesire (1 ciclu) care indica finalizarea calculului
    output     [2:0]                        dbg_state                      // Semnal de ieșire pentru depanare: starea curenta a FSM
);

    // -------------------------------------------------------------------
    // Latimi interne: diferentele pot creste cu 1 bit fata de coordonate,
    // produsul dintre 2 diferente dubleaza latimea, iar scaderea a 2
    // produse mai adauga 1 bit de siguranta.
    // -------------------------------------------------------------------
    localparam DIFF_BITS = COORD_BITS + 1;                                 // Latimea de biti pentru diferente (scaderi)
    localparam PROD_BITS = 2 * DIFF_BITS;                                  // Latimea de biti pentru rezultatul inmultirilor
    localparam E_BITS    = PROD_BITS + 1;                                  // Latimea de biti pentru valoarea functiei de muchie

    // ------------------------
    // Definitie stari FSM
    // ------------------------
    localparam IDLE      = 3'b000,                                         // Starea de asteptare a comenzii start
               LOAD      = 3'b001,                                         // Starea de memorare a intrarilor in registre
               MULT      = 3'b011,                                         // Starea de calcul al produselor partiale
               SUB_STORE = 3'b100,                                         // Starea de calcul al diferentei E, salvare si trecere la muchia urmatoare
               DONE_ST   = 3'b101;                                         // Starea finala: generare impuls valid

    reg [2:0] state, next_state;                                           // Registrul de stare si semnalul pentru starea urmatoare
    assign dbg_state = state;                                              // Atribuirea starii curente pe ieșirea de depanare

    // -------------------------------------------------------------------
    // Registre pentru varfuri + punct testat (latch la LOAD)
    // -------------------------------------------------------------------
    reg signed [COORD_BITS-1:0] r_px, r_py;                                // Registre interne pentru punctul testat
    reg signed [COORD_BITS-1:0] r_x0, r_y0, r_x1, r_y1, r_x2, r_y2;        // Registre interne pentru cele 3 varfuri ale triunghiului
    
    // Contor muchie curenta (0,1,2) si acumulator de semne
    reg [1:0] edge_idx;                                                    // Contor pentru parcurgerea celor 3 muchii (0, 1, 2)
    
    // -------------------------------------------------------------------
    // Selectie (xA,yA)->(xB,yB) in functie de muchia curenta
    // -------------------------------------------------------------------
    reg signed [COORD_BITS-1:0] xA, yA, xB, yB;                            // Coordonatele temporare ale segmentului de muchie curent

    always @(*) begin                                                      // Bloc combinational pentru multiplexarea coordonatelor muchiei
        case (edge_idx)
            2'd0: begin xA=r_x0; yA=r_y0; xB=r_x1; yB=r_y1; end            // Muchia 0: de la V0 (x0,y0) la V1 (x1,y1)
            2'd1: begin xA=r_x1; yA=r_y1; xB=r_x2; yB=r_y2; end            // Muchia 1: de la V1 (x1,y1) la V2 (x2,y2)
            default: begin xA=r_x2; yA=r_y2; xB=r_x0; yB=r_y0; end         // Muchia 2: de la V2 (x2,y2) la V0 (x0,y0)
        endcase
    end

    // -------------------------------------------------------------------
    // Diferente si produse (multiplicare INTREAGA simpla, NU Q-format)
    // -------------------------------------------------------------------
    wire signed [DIFF_BITS-1:0] d_px_xA = r_px - xA;                       // Calculul diferentei pe X dintre punctul testat si varful A
    wire signed [DIFF_BITS-1:0] d_yB_yA = yB - yA;                         // Calculul diferentei pe Y dintre varfurile B si A (coeficientul A)
    wire signed [DIFF_BITS-1:0] d_py_yA = r_py - yA;                       // Calculul diferentei pe Y dintre punctul testat si varful A
    wire signed [DIFF_BITS-1:0] d_xB_xA = xB - xA;                         // Calculul diferentei pe X dintre varfurile B si A (coeficientul B)

    reg signed [PROD_BITS-1:0] prod1, prod2;                               // Registre pentru stocarea rezultatelor celor doua inmultiri


    // ------------------------
    // FSM - Calea de control
    // ------------------------
    always @(posedge clk or negedge rst_n) begin                           // Registru de stare sincronizat pe frontul crescator al ceasului
        if (!rst_n) state <= IDLE;                                         // Resetare stare FSM la IDLE pe reset activ
        else        state <= next_state;                                   // Tranzitie la starea urmatoare
    end

    always @(*) begin                                                      // Bloc combinational pentru calculul starii urmatoare FSM
        case (state)
            IDLE:      next_state = start ? LOAD : IDLE;                   // Din IDLE se trece in LOAD daca start este '1'
            LOAD:      next_state = MULT;                                  // Din LOAD se trece direct in MULT
            MULT:      next_state = SUB_STORE;                             // Din MULT se trece direct in SUB_STORE
            SUB_STORE: next_state = (edge_idx == 2'd2) ? DONE_ST : MULT;   // Daca s-au procesat toate 3 muchiile merge la DONE_ST, altfel relua MULT
            DONE_ST:   next_state = IDLE;                                  // Din DONE_ST se revine in IDLE
            default:   next_state = IDLE;                                  // Tratare caz implicit (siguranta FSM)
        endcase
    end

    // ------------------------
    // FSM - Calea de date
    // ------------------------
    always @(posedge clk or negedge rst_n) begin                           // Bloc secvential pentru executia operatiilor de date
        if (!rst_n) begin                                                  // Initializare registre la reset
            r_px <= 0; r_py <= 0;                                          // Resetare registre punct testat
            r_x0 <= 0; r_y0 <= 0;                                          // Resetare registre varf 0
            r_x1 <= 0; r_y1 <= 0;                                          // Resetare registre varf 1
            r_x2 <= 0; r_y2 <= 0;                                          // Resetare registre varf 2

            edge_idx  <= 0;                                                // Resetare contor muchie

            prod1 <= 0; prod2 <= 0;                                        // Resetare registre produse

            E0_out <= 0; E1_out <= 0; E2_out <= 0;                         // Resetare registre de ieșire pentru valorile E
            A0_out <= 0; A1_out <= 0; A2_out <= 0;                         // Resetare registre de ieșire pentru coeficientii A
            B0_out <= 0; B1_out <= 0; B2_out <= 0;                         // Resetare registre de ieșire pentru coeficientii B
            
            valid     <= 1'b0;                                             // Resetare semnal de validare
        end else begin

            valid <= 1'b0;   // puls de 1 ciclu, implicit 0                // Dezactivare implicita a semnalului valid pe fiecare ciclu de ceas

            case (state)

                IDLE: begin                                                
                    // In IDLE nu se efectueaza nicio modificare, așteaptă start
                end

                LOAD: begin                                                // Incarcarea valorilor de intrare in registrele interne
                    r_px <= px; r_py <= py;                                // Esantionare coordonate punct testat
                    r_x0 <= x0; r_y0 <= y0;                                // Esantionare coordonate V0
                    r_x1 <= x1; r_y1 <= y1;                                // Esantionare coordonate V1
                    r_x2 <= x2; r_y2 <= y2;                                // Esantionare coordonate V2
                    edge_idx  <= 2'd0;                                     // Initializare contor pentru prima muchie (0)
                end

                MULT: begin                                              
                    // multiplicare intreaga, 1 ciclu (sintetizata pe DSP)
                    prod1 <= d_px_xA * d_yB_yA;                            // Calcul produs 1: (px - xA) * (yB - yA)
                    prod2 <= d_py_yA * d_xB_xA;                            // Calcul produs 2: (py - yA) * (xB - xA)
                end

                SUB_STORE: begin       
                    // Etapa de scadere, stocare si avans contor                                    
                    // Inregistram atat conditia >=0 cat si <=0
                    case (edge_idx)                                      
                            2'd0: begin
                                E0_out <= prod1 - prod2; // Valoarea reala E0 = (px-xA)*(yB-yA) - (py-yA)*(xB-xA)
                                A0_out <= d_yB_yA;       // Coeficientul A0 (pasul pe X)                           
                                B0_out <= d_xB_xA;       // Coeficientul B0 (pasul pe Y)                          
                            end
                            2'd1: begin
                                E1_out <= prod1 - prod2; // Valoarea reala E1                                    
                                A1_out <= d_yB_yA;       // Coeficientul A1                                       
                                B1_out <= d_xB_xA;       // Coeficientul B1                                       
                            end
                            2'd2: begin
                                E2_out <= prod1 - prod2; // Valoarea reala E2                 
                                A2_out <= d_yB_yA;       // Coeficientul A2                                 
                                B2_out <= d_xB_xA;       // Coeficientul B2                              
                            end
                        endcase 

                    // Incrementare contor pentru trecerea la muchia urmatoare
                    edge_idx <= edge_idx + 2'd1;                           
                end

                DONE_ST: begin       
                    // Starea de finalizare
                                                          
                    // interior daca toate cele 3 semne sunt identice
                    valid <= 1'b1;                                     
                end

            endcase
        end
    end

endmodule // calc_corner
