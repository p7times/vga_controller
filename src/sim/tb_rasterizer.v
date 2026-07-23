`timescale 1ns / 1ps

module tb_rasterizer;

    parameter COORD_W  = 12;
    parameter SCREEN_W = 320;
    parameter SCREEN_H = 240;
    parameter PER      = 40;   // Clock 25 MHz

    reg clk = 0;
    always #(PER/2) clk = ~clk;

    reg rst_n;
    reg start;

    reg signed [COORD_W-1:0] x0, y0, x1, y1, x2, y2;

    wire signed [COORD_W-1:0] pixel_x, pixel_y;
    wire pixel_inside;
    wire pixel_valid;
    wire done;

    integer error_count = 0;
    integer test_count  = 0;
    integer total_pixels_checked = 0;

    // Instantiere Modul de Testat (DUT)
    rasterizer #(
        .COORD_W(COORD_W),
        .SCREEN_W(SCREEN_W),
        .SCREEN_H(SCREEN_H)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .pixel_inside(pixel_inside),
        .pixel_valid(pixel_valid),
        .done(done)
    );

    // -------------------------------------------------------------------
    // Model de referinta: Calculeaza starea (inside/outside) pentru 
    // un pixel specific (px, py) raportat la triunghi
    // -------------------------------------------------------------------
    function automatic expected_inside;
        input signed [COORD_W-1:0] t_px, t_py;
        input signed [COORD_W-1:0] t_x0, t_y0, t_x1, t_y1, t_x2, t_y2;

        integer e0, e1, e2;
        begin
            e0 = (t_px - t_x0) * (t_y1 - t_y0) - (t_py - t_y0) * (t_x1 - t_x0);
            e1 = (t_px - t_x1) * (t_y2 - t_y1) - (t_py - t_y1) * (t_x2 - t_x1);
            e2 = (t_px - t_x2) * (t_y0 - t_y2) - (t_py - t_y2) * (t_x0 - t_x2);

            expected_inside = ((e0 >= 0) && (e1 >= 0) && (e2 >= 0)) ||
                              ((e0 <= 0) && (e1 <= 0) && (e2 <= 0));
        end
    endfunction

    // -------------------------------------------------------------------
    // Task: Ruleaza rasterizarea pentru un triunghi si verifica TOTI pixelii
    // -------------------------------------------------------------------
    task run_test_triangle;
        input signed [COORD_W-1:0] t_x0, t_y0;
        input signed [COORD_W-1:0] t_x1, t_y1;
        input signed [COORD_W-1:0] t_x2, t_y2;
        input integer idx;

        integer local_errors;
        reg exp_inside;
        begin
            local_errors = 0;

            x0 = t_x0; y0 = t_y0;
            x1 = t_x1; y1 = t_y1;
            x2 = t_x2; y2 = t_y2;

            // Pornire FSM
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Colectam si verificam pixelii emis de rasterizator pe parcurs
            while (!done) begin
                @(posedge clk);
                #1; // Mici intarzieri pentru sampling dupa frontul de ceas

                if (pixel_valid) begin
                    total_pixels_checked = total_pixels_checked + 1;
                    
                    // Calculam ce trebuia sa fie pixelul conform Golden Model
                    exp_inside = expected_inside(pixel_x, pixel_y, t_x0, t_y0, t_x1, t_y1, t_x2, t_y2);

                    if (pixel_inside !== exp_inside) begin
                        local_errors = local_errors + 1;
                        error_count  = error_count + 1;
                        $display("  [EROARE Triunghi %0d] Pixel(%0d, %0d) -> DUT_inside=%b, Asteptat=%b",
                                 idx, pixel_x, pixel_y, pixel_inside, exp_inside);
                    end
                end
            end

            test_count = test_count + 1;

            if (local_errors == 0) begin
                $display("OK [%0d]: Triunghiul (%0d,%0d) (%0d,%0d) (%0d,%0d) rasterizat cu succes!",
                         idx, t_x0, t_y0, t_x1, t_y1, t_x2, t_y2);
            end else begin
                $display("ESEC [%0d]: Triunghiul (%0d,%0d) (%0d,%0d) (%0d,%0d) a avut %0d pixeli gresiti!",
                         idx, t_x0, t_y0, t_x1, t_y1, t_x2, t_y2, local_errors);
            end

            // Pauza mica intre teste
            repeat (2) @(posedge clk);
        end
    endtask

    // Helper pentru generat coordonate aleatorii valide in intervalul [MIN, MAX]
    function signed [COORD_W-1:0] rand_coord;
        input integer min_val, max_val;
        integer range;
        begin
            range = max_val - min_val + 1;
            rand_coord = min_val + ($urandom_range(0, range - 1));
        end
    endfunction

    integer test_idx;
    integer NUM_TRIUNGHIURI_ALEATORII = 200; // Poti schimba numarul de triunghiuri aici

    initial begin
        $display("=== START TEST AUTOMAT & ALEATORIU rasterizer ===");

        rst_n = 0; start = 0;
        x0 = 0; y0 = 0; x1 = 0; y1 = 0; x2 = 0; y2 = 0;
        
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------------
        // 1. Teste deterministe de baza
        // -------------------------------------------------------------------
        $display("--> Rulare teste de baza (triunghiuri fixe)...");
        
        // Triunghi mic in interiorul ecranului
        run_test_triangle(100, 100,  200, 100,  150, 200, 1);
        
        // Triunghi subtire/alungit
        run_test_triangle(50, 50,    400, 60,   200, 70,  2);

        // Triunghi cu coordonate negative si clamp la margini
        run_test_triangle(-50, -50,  100, -20,  50, 100,  3);

        // -------------------------------------------------------------------
        // 2. Teste Masive Aleatorii
        // -------------------------------------------------------------------
        $display("--> Rulare %0d triunghiuri aleatorii...", NUM_TRIUNGHIURI_ALEATORII);

        for (test_idx = 1; test_idx <= NUM_TRIUNGHIURI_ALEATORII; test_idx = test_idx + 1) begin
            // Generam triunghiuri cu varfuri in limitele sau usor in afara ecranului [0..640, 0..480]
            run_test_triangle(
                rand_coord(-20, SCREEN_W + 20), rand_coord(-20, SCREEN_H + 20),
                rand_coord(-20, SCREEN_W + 20), rand_coord(-20, SCREEN_H + 20),
                rand_coord(-20, SCREEN_W + 20), rand_coord(-20, SCREEN_H + 20),
                test_idx + 10
            );

            // Progres afisat la fiecare 50 de triunghiuri
            if (test_idx % 50 == 0) begin
                $display("   [Progres] Executat %0d / %0d triunghiuri... Erori total pixeli: %0d",
                         test_idx, NUM_TRIUNGHIURI_ALEATORII, error_count);
            end
        end

        // -------------------------------------------------------------------
        // Raport Final
        // -------------------------------------------------------------------
        $display("--------------------------------------------------");
        $display("Total triunghiuri testate : %0d", test_count);
        $display("Total pixeli verificati   : %0d", total_pixels_checked);
        $display("Total erori pixeli        : %0d", error_count);
        $display("--------------------------------------------------");
        
        if (error_count == 0)
            $display("=== SUCCES! Toate cele %0d triunghiuri au fost rasterizate cu 0 erori! ===", test_count);
        else
            $display("=== ESEC! S-au gasit %0d erori la nivel de pixel. Verifica log-ul! ===", error_count);

        $finish;
    end

endmodule
