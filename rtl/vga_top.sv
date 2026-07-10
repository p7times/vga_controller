`timescale 1ns / 1ps

module vga_top #(

    parameter int color_w = 4,                              // Numărul de biți pentru canalele R,G,B (determina nr max de culori reprezentabile)
    parameter logic [color_w-1:0] image_red   = 4'h0,       // Valoarea pentru canalul roșu al culorii de test
    parameter logic [color_w-1:0] image_green = 4'hF,       // Valoarea pentru canalul verde al culorii de test
    parameter logic [color_w-1:0] image_blue  = 4'hD        // Valoarea pentru canalul albastru al culorii de test

)(

    input  logic clk_100MHz,                                // Ceasul setat din constrângeri (100 MHz)
    input  logic btnC,                                      // activ pe 1 (butonul de pe placa)

    output logic hsync,                                     // Semnal de sincronizare pentru desenare pe orizontală (propagat din vga_driver)
    output logic vsync,                                     // Semnal de sincronizare pentru desenare pe verticală (propagat din vga_driver)

    output logic rst_led,                                   // LED de pe placa (pinul U16), aprins cat timp butonul de reset e apasat

    output logic [color_w-1:0] vga_red,                     // Semnal de ieșire: canalul roșu (propagat din vga_driver)
    output logic [color_w-1:0] vga_green,                   // Semnal de ieșire: canalul verde (propagat din vga_driver)
    output logic [color_w-1:0] vga_blue                     // Semnal de ieșire: canalul albastru (propagat din vga_driver)

);

    // =========================================================================
    // ceas de pixel generat din clocking wizard (mmcm/pll)
    // =========================================================================

    logic reset;                                            // Semnalul de reset intern, activ pe 1 (aceeasi polaritate ca btnC)

    assign rst_led = reset;                                 // LED-ul urmareste direct starea reset-ului: aprins cat timp reset=1 (buton apasat)
    assign reset   = btnC;                                  // Reset-ul preia direct starea butonului de pe placa, fara procesare suplimentara

    logic pix_clk;                                          // Ceasul de pixel, generat din clk_100MHz prin clocking wizard (mmcm/pll)

    vga_ctrl_block_wrapper vga_ctrl_block_wrapper_i (

        .clk_100MHz (clk_100MHz),                           // Intrare: ceasul de sistem al placii (100 MHz)
        .clk_out1_0 (pix_clk),                              // Iesire: ceasul de pixel generat (folosit mai jos de vga_driver)
        .reset_rtl_0(reset)                                 // Intrare: reset-ul wizard-ului, activ pe 1, acelasi semnal ca la buton

    );

    // =========================================================================
    // vga driver
    // =========================================================================

    vga_driver #(

        .color_w    (color_w),                              // Propaga latimea de biti per canal catre vga_driver
        .image_red  (image_red),                            // Propaga valoarea canalului rosu al culorii de test
        .image_green(image_green),                          // Propaga valoarea canalului verde al culorii de test
        .image_blue (image_blue)                            // Propaga valoarea canalului albastru al culorii de test

    ) vga_driver_i (

        .pix_clk  (pix_clk),                                // Conectat la ceasul de pixel generat mai sus
        .rst_n    (~reset),                                 // Conectat la reset inversat: vga_driver asteapta rst_n activ pe 0, iar reset e activ pe 1

        .hsync    (hsync),                                  // Iesirea de hsync a vga_driver e propagata direct catre portul de top
        .vsync    (vsync),                                  // Iesirea de vsync a vga_driver e propagata direct catre portul de top

        .vga_red  (vga_red),                                // Iesirea de culoare rosie a vga_driver e propagata direct catre portul de top
        .vga_green(vga_green),                              // Iesirea de culoare verde a vga_driver e propagata direct catre portul de top
        .vga_blue (vga_blue)                                // Iesirea de culoare albastra a vga_driver e propagata direct catre portul de top

    );

endmodule