`timescale 1ns / 1ps

module tb_vga_top;

    // -------------------------------------------------------------------
    // Parametri rezoluție fizică (trebuie să corespundă cu H_RES și V_RES din vga_top)
    // -------------------------------------------------------------------
    parameter H_RES = 640;
    parameter V_RES = 480;
    parameter NUM_FRAMES_TO_CAPTURE = 10;   // Numărul de cadre .bmp exportate

    // -------------------------------------------------------------------
    // Semnale pentru conectarea la DUT (Device Under Test)
    // -------------------------------------------------------------------
    reg        clk_100MHz;
    reg        btnC;
    reg  [5:0] sw;

    wire       hsync;
    wire       vsync;
    wire       rst_led;
    wire [3:0] an;
    wire [6:0] seg;
    wire       dp;
    wire [3:0] vga_red;
    wire [3:0] vga_green;
    wire [3:0] vga_blue;

    // -------------------------------------------------------------------
    // Generare Ceas 100 MHz (Perioadă 10 ns)
    // -------------------------------------------------------------------
    initial clk_100MHz = 0;
    always #5 clk_100MHz = ~clk_100MHz;

    // -------------------------------------------------------------------
    // Instanțiere DUT (vga_top)
    // -------------------------------------------------------------------
    vga_top #(
        .color_w(4),
        .H_RES_LOGIC(320),
        .V_RES_LOGIC(240),
        .H_RES(H_RES),
        .V_RES(V_RES)
    ) uut (
        .clk_100MHz (clk_100MHz),
        .btnC       (btnC),
        .sw         (sw),
        
        .hsync      (hsync),
        .vsync      (vsync),
        .rst_led    (rst_led),
        .an         (an),
        .seg        (seg),
        .dp         (dp),
        
        .vga_red    (vga_red),
        .vga_green  (vga_green),
        .vga_blue   (vga_blue)
    );

    // -------------------------------------------------------------------
    // Buffer local pentru un cadru capturat
    // Stocăm culori de 12 biți (4 biți Red, 4 biți Green, 4 biți Blue)
    // -------------------------------------------------------------------
    reg [11:0] captured_frame [0:H_RES*V_RES-1];
    integer frame_number;

    // -------------------------------------------------------------------
    // TASK: Captura unui cadru video complet pe baza semnalelor interne
    // Folosim accesul ierarhic la semnalele din vga_top:
    // uut.pix_clk, uut.phys_x, uut.phys_y, uut.vde_raw
    // -------------------------------------------------------------------
    task capture_one_frame;
        begin
            // Așteptăm începutul unui cadru nou prin frontul descrescător al VSYNC
            @(negedge vsync);

            fork
                begin : sample_loop
                    forever begin
                        @(posedge uut.pix_clk);
                        // Când semnalul Video Data Enable (VDE) este activ, eșantionăm culoarea
                        if (uut.vde_raw) begin
                            captured_frame[(uut.phys_y * H_RES) + uut.phys_x] <= {vga_red, vga_green, vga_blue};
                        end
                    end
                end
                begin
                    // Când apare următorul VSYNC descrescător, cadrul s-a terminat
                    @(negedge vsync);
                    disable sample_loop;
                end
            join
        end
    endtask

    // -------------------------------------------------------------------
    // TASK: Exportul buffer-ului în fișier .BMP (24-bit RGB)
    // -------------------------------------------------------------------
    integer file_id, x, y;
    reg [31:0] bmp_file_size;
    reg [8*50-1:0] filename_dynamic;
    reg [11:0] pixel_color;
    reg [7:0]  r8, g8, b8;

    task export_captured_frame_to_bmp;
        input integer frame_index;
        begin
            bmp_file_size = 54 + (H_RES * V_RES * 3);
            // ATENȚIE: Folderul "output_frames" trebuie să existe manual în directorul de simulare!
            $sformat(filename_dynamic, "output_frames/vga_frame_%03d.bmp", frame_index);

            file_id = $fopen(filename_dynamic, "wb");
            if (!file_id) begin
                $display("[EROARE] Nu pot deschide/crea fișierul %s. Verifică dacă folderul 'output_frames' există!", filename_dynamic);
                $finish;
            end

            // Scriere Header BMP (54 octeți)
            $fwrite(file_id, "%c%c", "B", "M");
            $fwrite(file_id, "%c%c%c%c", bmp_file_size[7:0], bmp_file_size[15:8], bmp_file_size[23:16], bmp_file_size[31:24]);
            $fwrite(file_id, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h36, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h28, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", H_RES[7:0], H_RES[15:8], H_RES[23:16], H_RES[31:24]);
            $fwrite(file_id, "%c%c%c%c", V_RES[7:0], V_RES[15:8], V_RES[23:16], V_RES[31:24]);
            $fwrite(file_id, "%c%c", 8'h01, 8'h00);
            $fwrite(file_id, "%c%c", 8'h18, 8'h00); // 24 biți per pixel (RGB)
            $fwrite(file_id, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h13, 8'h0B, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h13, 8'h0B, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);
            $fwrite(file_id, "%c%c%c%c", 8'h00, 8'h00, 8'h00, 8'h00);

            // Scrierile în format BMP se fac de jos în sus (Rândul V_RES-1 până la 0)
            for (y = V_RES-1; y >= 0; y = y-1) begin
                for (x = 0; x < H_RES; x = x+1) begin
                    pixel_color = captured_frame[(y*H_RES)+x];
                    
                    // Extragem cele 3 canale (câte 4 biți) și le duplicăm la 8 biți
                    // Ex: 4'hF devine 8'hFF (0 -> 0, max -> 255)
                    r8 = {pixel_color[11:8], pixel_color[11:8]};
                    g8 = {pixel_color[7:4],  pixel_color[7:4]};
                    b8 = {pixel_color[3:0],  pixel_color[3:0]};
                    
                    // Formatul BMP cere ordinea Blue, Green, Red
                    $fwrite(file_id, "%c%c%c", b8, g8, r8); 
                end
            end

            $fclose(file_id);
            $display("[SUCCES] Salvat cadru: %s (Timp simulare: %0d us)", filename_dynamic, $time/1000);
        end
    endtask

    // -------------------------------------------------------------------
    // SCENARIU DE TESTARE
    // -------------------------------------------------------------------
    initial begin
        $display("=== START SIMULARE SI CAPTURA CADRE VGA ===");

        // Stare inițială
        sw   = 6'b101011; // Poți seta switch-urile în funcție de ce controlează ele în triangle_controller
        btnC = 1'b1;      // Reset activ (activ-high la tine în vga_top)

        // Aplicăm resetul pentru 200 ns
        #200;
        btnC = 1'b0;

        // Așteptăm stabilizarea ceasului (MMCM/PLL din vga_ctrl_block_wrapper)
        // și primul cadru
        $display("[INFO] Astept stabilizarea sistemului dupa reset...");
        #100000;

        // --- BUCLE DE CAPTURĂ ---
        
        // 1. Capturăm primele 5 cadre cu sw = 6'b000001
        for (frame_number = 0; frame_number < 5; frame_number = frame_number + 1) begin
            $display("[INFO] Capturez cadrul %0d...", frame_number);
            capture_one_frame();
            export_captured_frame_to_bmp(frame_number);
        end

        // 2. Schimbăm switch-urile pentru a testa comportamentul dinamic (ex: altă direcție/viteză)
        $display("[INFO] Schimb valoarea switch-urilor (sw = 6'b000010)...");
        sw = 6'b000010;
        
        for (frame_number = 5; frame_number < NUM_FRAMES_TO_CAPTURE; frame_number = frame_number + 1) begin
            $display("[INFO] Capturez cadrul %0d...", frame_number);
            capture_one_frame();
            export_captured_frame_to_bmp(frame_number);
        end

        $display("=== FINAL SIMULARE. Au fost exportate %0d cadre. ===", NUM_FRAMES_TO_CAPTURE);
        $finish;
    end

endmodule