`timescale 1ns / 1ps

module vga_top #(
    parameter int color_w = 4,  // Color depth (lungimea în biți pentru un canal R/G/B)
    
    // Culoare fundal
    parameter logic [color_w-1:0] bg_red   = 4'h2,
    parameter logic [color_w-1:0] bg_green = 4'h2,
    parameter logic [color_w-1:0] bg_blue  = 4'h2
)(
    input  logic clk_100MHz,                // Ceas sistem
    input  logic btnC,                      // Buton reset
    
    output logic hsync,                     // Semnal de sincronizare orizontală 
    output logic vsync,                     // Semnal de sincronizare verticală 
    output logic rst_led,                   // LED pentru reset
    
    output logic [color_w-1:0] vga_red,     // Canal VGA pentru roșu
    output logic [color_w-1:0] vga_green,   // Canal VGA pentru verde
    output logic [color_w-1:0] vga_blue     // Canal VGA pentru albastru
);

    logic reset;
    assign rst_led = reset;
    assign reset   = btnC;

    logic pix_clk;

    // Wizard-ul pentru ceas 
    // Frecventa lucru: H_TOTAL * V_TOTAL * FPS
    // Pentru 640x480p, 60 FPS: 800 * 525 * 60 =  25.175 MHz
    vga_ctrl_block_wrapper vga_ctrl_block_wrapper_i (
        .clk_100MHz (clk_100MHz),
        .clk_out1_0 (pix_clk),
        .reset_rtl_0(reset)
    );

    // =========================================================================
    // SEMNALE DE INTERCONECTARE ÎNTRE DRIVER ȘI RENDERER
    // =========================================================================
    logic [9:0] current_x;
    logic [9:0] current_y;
    
    logic [color_w-1:0] shape_red;
    logic [color_w-1:0] shape_green;
    logic [color_w-1:0] shape_blue;

    // =========================================================================
    // SHAPE RENDERER
    // =========================================================================
    shape_renderer #(
        .color_w (color_w),
        .bg_red  (bg_red),
        .bg_green(bg_green),
        .bg_blue (bg_blue)
    ) shape_renderer_i (
        .h_pos    (current_x),   // Primește coordonata de la vga_driver
        .v_pos    (current_y),   // Primește coordonata de la vga_driver
        
        .pix_red  (shape_red),   // Trimite culoarea calculată afară
        .pix_green(shape_green),
        .pix_blue (shape_blue)
    );

    // =========================================================================
    // VGA DRIVER
    // =========================================================================
    vga_driver #(
        .color_w (color_w)
    ) vga_driver_i (
        .pix_clk  (pix_clk),
        .rst_n    (~reset),
        
        .h_pos    (current_x),   // Trimite coordonata X către renderer
        .v_pos    (current_y),   // Trimite coordonata Y către renderer
        
        .pix_red  (shape_red),   // Primește culoarea de la renderer
        .pix_green(shape_green), // Primește culoarea de la renderer
        .pix_blue (shape_blue),  // Primește culoarea de la renderer

        .hsync    (hsync),
        .vsync    (vsync),
        .vga_red  (vga_red),
        .vga_green(vga_green),
        .vga_blue (vga_blue)
    );

endmodule