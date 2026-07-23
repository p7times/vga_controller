//---------------------------------------------------------------
// Proiect    : VGA Triangle Rasterizer
// Modul      : vga_top
// Autor      : Petru-Andrei BRASOVEANU  
// An         : 2026
//------------------------------------------------------------------------------
// Descriere : Modulul TOP al sistemului grafic VGA. Interconectează ceasul, 
//             generatorul de coordonate triunghiulare (`triangle_controller`), 
//             modulul de randare (`shape_renderer`), driverul VGA și 
//             interfața de framebuffer. Include și un afișor de FPS pe 7 segmente.
//------------------------------------------------------------------------------

`timescale 1ns / 1ps

module vga_top #(
    parameter color_w       = 4,                                    // Lățimea semnalului de culoare (4 biți per R/G/B)
    parameter H_RES_LOGIC   = 320,                                  // Rezoluție orizontală în memorie
    parameter V_RES_LOGIC   = 240,                                  // Rezoluție verticală în memorie
    parameter FB_ADDR_WIDTH = $clog2(H_RES_LOGIC * V_RES_LOGIC),    // Lățimea adresei din Framebuffer
    parameter H_RES         = 640,                                  // Rezoluție fizică VGA (Orizontală)
    parameter V_RES         = 480                                   // Rezoluție fizică VGA (Verticală)
)(
    input  wire               clk_100MHz, // Semnalul de ceas principal al plăcii FPGA (100 MHz)
    input  wire               btnC,       // Butonul central (folosit ca Reset general)
    input  wire [5:0]         sw,         // Comutatoare de pe placă (comandedă animația triunghiului)

    output wire               hsync,      // Semnal HSYNC transmis ecranului VGA
    output wire               vsync,      // Semnal VSYNC transmis ecranului VGA
    output wire               rst_led,    // LED indicator pentru stare de Reset

    output      [3:0]         an,         // Anozii celor 4 afișaje pe 7 segmente
    output      [6:0]         seg,        // Catozii (segmentele A-G) ale afișajului
    output                    dp,         // Punctul zecimal al afișajului
    
    output wire [color_w-1:0] vga_red,    // Ieșire DAC Roșu (4 biți)
    output wire [color_w-1:0] vga_green,  // Ieșire DAC Verde (4 biți)
    output wire [color_w-1:0] vga_blue    // Ieșire DAC Albastru (4 biți)
);

    // =========================================================================
    // RESET / CEAS (Clock Generator & Synchronization)
    // =========================================================================
    wire reset;      // Reset activ-HIGH
    wire reset_n;    // Reset activ-LOW
    wire pix_clk;    // Ceasul generat de pixel (25.175 MHz)

    assign rst_led = reset;
    assign reset   = btnC;
    assign reset_n = ~reset;

    // Generarea ceasului de pixel folosind un IP/Wrapper de Clocking Wizard (MMCM/PLL)
    vga_ctrl_block_wrapper vga_ctrl_block_wrapper_i (
        .clk_100MHz (clk_100MHz),
        .clk_out1_0 (pix_clk),
        .reset_rtl_0(reset)
    );

    // =========================================================================
    // TRIANGLE CONTROLLER (Generare coordonate geometrice)
    // =========================================================================
    wire [$clog2(H_RES_LOGIC)-1:0] tri_x0, tri_x1, tri_x2;
    wire [$clog2(V_RES_LOGIC)-1:0] tri_y0, tri_y1, tri_y2;

    triangle_controller #(
        .H_ACTIVE (H_RES_LOGIC),
        .V_ACTIVE (V_RES_LOGIC)
    ) triangle_controller_i (
        .clk (pix_clk),
        .rst (reset),
        .sw  (sw),

        .x0(tri_x0), .y0(tri_y0),
        .x1(tri_x1), .y1(tri_y1),
        .x2(tri_x2), .y2(tri_y2)
    );

    // =========================================================================
    // VGA TIMING (Driver pentru semnalele fizice VGA)
    // =========================================================================
    wire [11:0] phys_x, phys_y;
    wire        hsync_raw, vsync_raw, vde_raw;

    vga_driver #(
        .COORD_BITS(12)
    ) vga_driver_i (
        .pixel_clk(pix_clk),
        .rst_n    (reset_n),

        .hsync    (hsync_raw),
        .vsync    (vsync_raw),
        .vde      (vde_raw),
        .pixel_x  (phys_x),
        .pixel_y  (phys_y)
    );

    // =========================================================================
    // DETECȚIE SINKING / PULS "start"
    // Generează un impuls la primul pixel fizic (0,0) pentru a începe desenarea
    // =========================================================================
    reg  frame_start_q;
    wire at_origin = (phys_x == 0) && (phys_y == 0);

    always @(posedge pix_clk or negedge reset_n) begin
        if (!reset_n) frame_start_q <= 1'b0;
        else          frame_start_q <= at_origin;
    end

    // Impuls scurt de un ciclu la orinea ecranului (X=0, Y=0)
    wire tri_start = at_origin && !frame_start_q;

    // =========================================================================
    // SHAPE RENDERER (Rasterizează triunghiul în framebuffer-ul dublu)
    // =========================================================================
    wire [FB_ADDR_WIDTH-1:0] fb_rd_addr;
    wire [color_w-1:0]        fb_rd_data;
    wire                     frame_done;

    shape_renderer #(
        .H_ACTIVE  (H_RES_LOGIC),
        .V_ACTIVE  (V_RES_LOGIC),
        .COLOR_BITS(color_w)
    ) shape_renderer_i (
        .clk      (pix_clk),
        .rst_n    (reset_n),
        .start    (tri_start),
        .color    ({color_w{1'b1}}), // Culoarea albă completă (toți biții pe 1)
        .done     (),

        .x0(tri_x0), .y0(tri_y0),
        .x1(tri_x1), .y1(tri_y1),
        .x2(tri_x2), .y2(tri_y2),

        .frame_end_pulse(frame_done), // Impuls primit la finalul parcurgerii cadrului

        .rd_address(fb_rd_addr),
        .rd_dataOut(fb_rd_data)
    );

    // =========================================================================
    // VGA FB INTERFACE (Adresare logică, scalare 2x2 și aliniere BRAM)
    // =========================================================================
    vga_fb_interface #(
        .COLOR_BITS   (color_w),
        .H_RES_LOGIC  (H_RES_LOGIC),
        .V_RES_LOGIC  (V_RES_LOGIC),
        .H_RES        (H_RES),
        .V_RES        (V_RES)
    ) vga_fb_interface_i (
        .pixel_clk (pix_clk),
        .rst_n     (reset_n),

        .hsync_i (hsync_raw),
        .vsync_i (vsync_raw),
        .vde_i   (vde_raw),
        .pixel_x (phys_x),
        .pixel_y (phys_y),

        .fb_video_data (fb_rd_data),
        .fb_video_addr (fb_rd_addr),

        .ready_internal (frame_done), // Emite pulsul de final de cadru când se ajunge la ultimul pixel

        .hsync_o (hsync),
        .vsync_o (vsync),
        .vga_red  (vga_red),
        .vga_green(vga_green),
        .vga_blue (vga_blue)
    );

    // =========================================================================
    // FPS COUNTER (Afișează numărul de cadre per secundă pe display-ul 7 segmente)
    // =========================================================================
    fps_counter u_fps_counter (
        .clk    (pix_clk),        // Ceasul de pixel
        .rst_n  (reset_n),        // Reset general
        .vsync  (frame_done),     // Puls de numărare cadru
        .an     (an),             // Comandă anozilor
        .seg    (seg),            // Comandă catozilor (segmente A-G)
        .dp     (dp)              // Punct zecimal
    );

endmodule // vga_top