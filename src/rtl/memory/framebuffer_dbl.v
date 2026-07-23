//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : framebuffer_dbl
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//---------------------------------------------------------------
// Descriere  : Instanțiază 2 buffere de memorie pentru bitmap și implementează
//              logica de swap: când se scrie într-un buffer, se citește în altul
//              și vice-versa.
//---------------------------------------------------------------

`timescale 1ns / 1ps

module framebuffer_dbl #(
    parameter H_RES         = 320,                                     // Rezolutia orizontala in pixeli
    parameter V_RES         = 240,                                     // Rezolutia verticala in pixeli
    parameter COLOR_BITS    = 4,                                       // Numarul de biti per pixel (adancimea de culoare)
    parameter FB_ADDR_WIDTH = $clog2(H_RES * V_RES)                    // Numarul de biti pentru adresarea intregului framebuffer
)(
    input                        clk,                                  // Semnalul de ceas principal
    input                        rst_n,                                // Semnalul de reset asincron, activ pe '0' (active low)

    // --- Interfata de SCRIERE (de la BU/rasterizator) - merge in bufferul din spate ---
    input                        cs,                                   // Semnal de selectie cip pentru scriere (Chip Select)
    input                        wr,                                   // Semnal de permisiune la scriere (Write Enable)
    input                        clear,                                // Comanda pentru stergerea bufferului de scriere
    input  [$clog2(H_RES)-1:0]   x_in,                                 // Coordonata X a pixelului ce urmeaza a fi scris
    input  [$clog2(V_RES)-1:0]   y_in,                                 // Coordonata Y a pixelului ce urmeaza a fi scris
    input  [COLOR_BITS-1:0]      pixel_in,                             // Valoarea culorii pixelului de scris
    output                       busy,                                 // Semnal de ocupat (busy) al bufferului curent din spate

    // --- Puls care marcheaza finalul unui cadru: swap disp_buf <-> write_buf ---
    input                        swap,                                 // Puls pentru comutarea bufferelor (double buffering)

    // --- Interfata de CITIRE (catre VGA/HDMI) - citeste bufferul din fata ---
    input  [FB_ADDR_WIDTH-1:0]   rd_address,                           // Adresa liniara citita de modulul de afisare (VGA/HDMI)
    output [COLOR_BITS-1:0]      rd_dataOut,                           // Datele (culoarea pixelului) citite din bufferul din fata
    
    output                       dbg_fb_i_state,                       // Semnal de depanare: starea FSM a primului framebuffer (FB0)
    output                       dbg_fb_ii_state,                      // Semnal de depanare: starea FSM al celui de-al doilea framebuffer (FB1)

    // --- Debug: care buffer e afisat curent (0 sau 1) ---
    output                       dbg_disp_buf                          // Semnal de depanare: indica bufferul afisat curent (0 sau 1)
);

    // -------------------------------------------------------------------
    // Selectie buffer: disp_buf = bufferul afisat acum (citit de VGA)
    // Bufferul scris e mereu opusul (~disp_buf).
    // -------------------------------------------------------------------
    reg disp_buf;                                                      // Registru care retine indexul bufferului afisat (0 sau 1)
    wire write_buf = ~disp_buf;                                        // Bufferul de scriere este intotdeauna opusul bufferului de afisare

    always @(posedge clk or negedge rst_n) begin                        // Proces secvential pentru comutarea bufferelor pe ceas
        if (!rst_n)                                                    // La reset asincron
            disp_buf <= 1'b0;                                          // Se initializeaza bufferul de afisare cu 0
        else if (swap)                                                 // La primirea impulsului swap
            disp_buf <= ~disp_buf;                                     // Se comuta bufferul afisat (0 devine 1, 1 devine 0)
    end

    assign dbg_disp_buf = disp_buf;                                    // Conectare semnal de afisare la iesirea de depanare

    // -------------------------------------------------------------------
    // Demultiplexare semnale de scriere catre cele 2 instante fizice
    // -------------------------------------------------------------------
    wire cs0    = (write_buf == 1'b1) ? 1'b0 : cs;                    // Semnal CS pentru FB0: activ doar daca write_buf este 0
    wire wr0    = (write_buf == 1'b1) ? 1'b0 : wr;                    // Semnal WR pentru FB0: activ doar daca write_buf este 0
    wire clear0 = (write_buf == 1'b1) ? 1'b0 : clear;                 // Semnal CLEAR pentru FB0: activ doar daca write_buf este 0

    wire cs1    = (write_buf == 1'b1) ? cs    : 1'b0;                 // Semnal CS pentru FB1: activ doar daca write_buf este 1
    wire wr1    = (write_buf == 1'b1) ? wr    : 1'b0;                 // Semnal WR pentru FB1: activ doar daca write_buf este 1
    wire clear1 = (write_buf == 1'b1) ? clear : 1'b0;                 // Semnal CLEAR pentru FB1: activ doar daca write_buf este 1

    wire busy0, busy1;                                                 // Semnale interne de busy de la cele doua FB-uri
    wire [COLOR_BITS-1:0] rd_dataOut0, rd_dataOut1;                   // Datele de iesire la citire de la cele doua FB-uri

    // busy expus in exterior = busy-ul bufferului tinta curent (din spate)
    assign busy = (write_buf == 1'b0) ? busy0 : busy1;                 // Multiplexare busy in functie de bufferul curent de scriere

    // rd_dataOut expus in exterior = bufferul afisat curent (din fata)
    assign rd_dataOut = (disp_buf == 1'b0) ? rd_dataOut0 : rd_dataOut1;// Multiplexare date citite in functie de bufferul curent de afisare

    // -------------------------------------------------------------------
    // Cele 2 instante fizice, nemodificate
    // -------------------------------------------------------------------
    framebuffer #(
        .H_RES(H_RES), .V_RES(V_RES), .COLOR_BITS(COLOR_BITS)          // Instantiere prima memorie de cadru (FB0) cu parametrii specificati
    ) u_fb0 (
        .clk(clk), .rst_n(rst_n),                                     // Conectare ceas si reset
        .cs(cs0), .wr(wr0), .clear(clear0),                            // Conectare semnale demultiplexate de control scriere
        .x_in(x_in), .y_in(y_in), .pixel_in(pixel_in),                 // Conectare coordonate si culoare pixel intrare
        .rd_address(rd_address), .rd_dataOut(rd_dataOut0),             // Conectare adresa si date iesire citire
        .busy(busy0),                                                  // Conectare starea busy FB0
        .dbg_clear_addr(), .dbg_state(dbg_fb_i_state)                  // Conectare semnale de depanare
    );

    framebuffer #(
        .H_RES(H_RES), .V_RES(V_RES), .COLOR_BITS(COLOR_BITS)          // Instantiere a doua memorie de cadru (FB1) cu parametrii specificati
    ) u_fb1 (
        .clk(clk), .rst_n(rst_n),                                     // Conectare ceas si reset
        .cs(cs1), .wr(wr1), .clear(clear1),                            // Conectare semnale demultiplexate de control scriere
        .x_in(x_in), .y_in(y_in), .pixel_in(pixel_in),                 // Conectare coordonate si culoare pixel intrare
        .rd_address(rd_address), .rd_dataOut(rd_dataOut1),             // Conectare adresa si date iesire citire
        .busy(busy1),                                                  // Conectare starea busy FB1
        .dbg_clear_addr(), .dbg_state(dbg_fb_ii_state)                 // Conectare semnale de depanare
    );

endmodule // framebuffer_dbl
