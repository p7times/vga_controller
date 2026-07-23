`timescale 1ns / 1ps

module tb_calc_corner;

    parameter COORD_BITS = 12;
    parameter PER        = 10;   // 100 MHz

    reg clk = 0;
    always #(PER/2) clk = ~clk;

    reg rst_n;
    reg start;

    reg signed [COORD_BITS-1:0] px, py;
    reg signed [COORD_BITS-1:0] x0, y0, x1, y1, x2, y2;

    wire is_inside;
    wire valid;
    wire [2:0] dbg_state;

    integer error_count = 0;
    integer test_count  = 0;

    calc_corner #(
        .COORD_BITS(COORD_BITS),
        .IS_INSIDE_SIGN_POSITIVE(1'b1)   // AJUSTEAZA daca testele manuale ies inversate
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .px(px), .py(py),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .is_inside(is_inside),
        .valid(valid),
        .dbg_state(dbg_state)
    );

    // -------------------------------------------------------------------
    // Model de referinta (calculat direct in testbench, in "real", ca
    // sa nu depindem de acelasi cod ca DUT-ul - un golden model independent)
    // -------------------------------------------------------------------
    function automatic expected_inside;
        input signed [COORD_BITS-1:0] t_px, t_py;
        input signed [COORD_BITS-1:0] t_x0, t_y0, t_x1, t_y1, t_x2, t_y2;

        integer e0, e1, e2;
        begin
            e0 = (t_px - t_x0) * (t_y1 - t_y0) - (t_py - t_y0) * (t_x1 - t_x0);
            e1 = (t_px - t_x1) * (t_y2 - t_y1) - (t_py - t_y1) * (t_x2 - t_x1);
            e2 = (t_px - t_x2) * (t_y0 - t_y2) - (t_py - t_y2) * (t_x0 - t_x2);

            // aceeasi conventie ca in DUT: toate >=0 SAU toate <=0
            expected_inside = ((e0 >= 0) && (e1 >= 0) && (e2 >= 0)) ||
                               ((e0 <= 0) && (e1 <= 0) && (e2 <= 0));
        end
    endfunction

    // -------------------------------------------------------------------
    // Task: ruleaza un test, compara cu modelul de referinta
    // -------------------------------------------------------------------
    task run_test;
        input signed [COORD_BITS-1:0] t_px, t_py;
        input signed [COORD_BITS-1:0] t_x0, t_y0, t_x1, t_y1, t_x2, t_y2;
        input integer idx;

        reg exp;
        begin
            px = t_px; py = t_py;
            x0 = t_x0; y0 = t_y0;
            x1 = t_x1; y1 = t_y1;
            x2 = t_x2; y2 = t_y2;

            exp = expected_inside(t_px, t_py, t_x0, t_y0, t_x1, t_y1, t_x2, t_y2);

            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            wait (valid == 1'b1);
            @(posedge clk); #1;

            test_count = test_count + 1;

            if (is_inside !== exp) begin
                error_count = error_count + 1;
                $display("EROARE [%0d]: punct(%0d,%0d) tri(%0d,%0d %0d,%0d %0d,%0d) -> DUT=%b asteptat=%b",
                          idx, t_px, t_py, t_x0, t_y0, t_x1, t_y1, t_x2, t_y2, is_inside, exp);
            end else begin
                $display("OK [%0d]: punct(%0d,%0d) -> is_inside=%b", idx, t_px, t_py, is_inside);
            end
        end
    endtask

    integer test_idx;
    integer NUM_TESTS_ALEATORII = 50000; // Schimba numarul de teste aici (ex: 10000, 100000)

    // Functie helper pentru generat numere semnate in intervalul coordinatei [MIN, MAX]
    function signed [COORD_BITS-1:0] rand_coord;
        input integer min_val, max_val;
        integer range;
        begin
            range = max_val - min_val + 1;
            // $urandom_range genereaza un număr pozitiv intre 0 si range-1
            rand_coord = min_val + ($urandom_range(0, range - 1));
        end
    endfunction

    initial begin
        $display("=== START TEST AUTOMAT & ALEATORIU calc_corner ===");

        rst_n = 0; start = 0;
        px=0; py=0; x0=0; y0=0; x1=0; y1=0; x2=0; y2=0;
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (2) @(posedge clk);

        // -------------------------------------------------------------------
        // 1. Teste deterministe de baza (Corner Cases)
        // -------------------------------------------------------------------
        $display("--> Rulare teste de baza...");
        run_test(50, 40,   10,10, 100,10, 50,100, 1);
        run_test(200, 200, 10,10, 100,10, 50,100, 2);
        run_test(10, 10,   10,10, 100,10, 50,100, 3);
        run_test(55, 10,   10,10, 100,10, 50,100, 4);

        // -------------------------------------------------------------------
        // 2. Teste Masive Aleatorii
        // -------------------------------------------------------------------
        $display("--> Rulare %0d teste aleatorii...", NUM_TESTS_ALEATORII);

        for (test_idx = 1; test_idx <= NUM_TESTS_ALEATORII; test_idx = test_idx + 1) begin
            // Generam coordonate aleatorii in intervalul [-2000, 2000]
            // Daca ai COORD_BITS=12, intervalul semnat valid este [-2048, 2047]
            run_test(
                rand_coord(-2000, 2000), rand_coord(-2000, 2000), // px, py
                rand_coord(-2000, 2000), rand_coord(-2000, 2000), // x0, y0
                rand_coord(-2000, 2000), rand_coord(-2000, 2000), // x1, y1
                rand_coord(-2000, 2000), rand_coord(-2000, 2000), // x2, y2
                test_idx + 100
            );

            // Afiseaza progresul la fiecare 10.000 de teste ca sa stii ca ruleaza
            if (test_idx % 10000 == 0) begin
                $display("   [Progres] Executat %0d / %0d teste... Erori pana acum: %0d", 
                         test_idx, NUM_TESTS_ALEATORII, error_count);
            end
        end

        // -------------------------------------------------------------------
        // Raport Final
        // -------------------------------------------------------------------
        $display("--------------------------------");
        $display("Total teste rulate : %0d", test_count);
        $display("Total erori        : %0d", error_count);
        
        if (error_count == 0)
            $display("=== SUCCES! Toate cele %0d teste au trecut cu 0 erori! ===", test_count);
        else
            $display("=== ESEC! S-au gasit %0d erori. Verifica log-ul de mai sus. ===", error_count);

        $finish;
    end

endmodule // tb_calc_corner
