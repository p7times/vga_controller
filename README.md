# VGA Controller

**Autor:** Brașoveanu Petru-Andrei

---

## Cuprins
- [VGA Controller](#vga-controller)
  - [Cuprins](#cuprins)
  - [1. Introducere](#1-introducere)
  - [2. Obiective](#2-obiective)
    - [2.1. Obiective proiect](#21-obiective-proiect)
    - [2.2. Obiective personalizate](#22-obiective-personalizate)
  - [3. Etape](#3-etape)
    - [3.1. Specificații](#31-specificații)
      - [3.1.1. Obiectiv](#311-obiectiv)
      - [3.1.2. Realizare](#312-realizare)
      - [3.1.3. Dificultăți](#313-dificultăți)
      - [3.1.4. Mod de rezolvare](#314-mod-de-rezolvare)
    - [3.2. Simulare](#32-simulare)
      - [3.2.1. Obiectiv](#321-obiectiv)
      - [3.2.2. Realizare](#322-realizare)
      - [3.2.3. Dificultăți](#323-dificultăți)
      - [3.2.4. Mod de rezolvare](#324-mod-de-rezolvare)
    - [3.3. Implementare](#33-implementare)
      - [3.3.1. Obiectiv](#331-obiectiv)
      - [3.3.2. Realizare](#332-realizare)
      - [3.3.3. Dificultăți](#333-dificultăți)
      - [3.3.4. Mod de rezolvare](#334-mod-de-rezolvare)
    - [3.4. Extindere: LED de stare reset și culoare personalizată](#34-extindere-led-de-stare-reset-și-culoare-personalizată)
      - [3.4.1. Obiectiv](#341-obiectiv)
      - [3.4.2. Realizare](#342-realizare)
      - [3.4.3. Dificultăți](#343-dificultăți)
      - [3.4.4. Mod de rezolvare](#344-mod-de-rezolvare)
    - [3.5. Etape următoare (planificate)](#35-etape-următoare-planificate)
      - [3.5.1. Obiectiv](#351-obiectiv)
      - [3.5.2. Realizare](#352-realizare)
      - [3.5.3. Dificultăți](#353-dificultăți)
      - [3.5.4. Mod de rezolvare](#354-mod-de-rezolvare)

---

## 1. Introducere

**Revizie:** 1.0. - afișarea unei culori solide pe monitor

Acest proiect urmărește conceperea unui controller VGA pentru un FPGA, capabil inițial să afișeze o culoare solidă pe monitor, urmând ca ulterior să afișeze o formă geometrică (funcție de decizii care vor fi luate pe parcurs, la implementare).

**Placă folosită:** Digilent Basys 3 (Xilinx Artix-7, `xc7a35ticpg236-1L`), ceas de sistem 100MHz.

**Module implicate:**

| Modul | Rol |
|---|---|
| `vga_driver` | Generator de timing VGA (numărători, sincronizări, blanking) + ieșire culoare |
| `vga_top` | Top-level pentru placă: instanțiază generatorul de ceas și `vga_driver`, gestionează reset-ul și LED-ul de stare |
| `vga_ctrl_block_wrapper` / `vga_ctrl_block` | Clocking wizard (MMCM), generează `pix_clk` din `clk_100MHz` |
| `tb_vga_top` | Testbench de verificare funcțională a `vga_driver` (timing, reset, blanking) |

---

## 2. Obiective

### 2.1. Obiective proiect
Cerința de bază a proiectului: proiectarea unui controller VGA funcțional pentru rezoluția 640x480 @ 60Hz, capabil să afișeze o imagine validă pe un monitor conectat la placa Basys 3, verificat atât prin simulare, cât și prin implementare reală pe FPGA.

### 2.2. Obiective personalizate
- Afișarea unei culori de test personalizate, aleasă pornind de la un cod hex web (`#00FFDA`).
- Adăugarea unui LED de stare pe placă, care indică vizual când butonul de reset e apăsat.
- Ca extindere ulterioară: afișarea unei forme geometrice pe monitor, în locul culorii solide.

---

## 3. Etape

### 3.1. Specificații

#### 3.1.1. Obiectiv
Definirea parametrilor de timing pentru rezoluția 640x480 @ 60Hz și a interfeței modulelor implicate (`vga_driver`, `vga_top`, `vga_ctrl_block_wrapper`), astfel încât proiectul să poată fi verificat printr-un testbench înainte de a exista implementarea propriu-zisă.

#### 3.1.2. Realizare
S-au stabilit:

- Parametrii de timing standard pentru 640x480@60Hz:
  - Orizontal: `h_active=640`, `h_fp=16`, `h_sync=96`, `h_bp=48` → `h_total=800`
  - Vertical: `v_active=480`, `v_fp=10`, `v_sync=2`, `v_bp=33` → `v_total=525`
  - Polaritate sincronizări: negativă (`h_pol=0`, `v_pol=0`)
- Interfața modulului `vga_driver`:
  - Intrări: `pix_clk`, `rst_n`
  - Ieșiri: `hsync`, `vsync`, `vga_red`, `vga_green`, `vga_blue`
  - Parametri: `color_w`, `image_red`, `image_green`, `image_blue` (culoare fixă folosită ca pattern de test)
- Un testbench (`tb_vga_top`) care modelează independent numărătorii de poziție (`model_h`, `model_v`) și compară, ciclu cu ciclu, ieșirile DUT-ului cu valorile așteptate.

#### 3.1.3. Dificultăți
- Definirea exactă a ferestrelor de sync (front porch / sync / back porch) astfel încât modelul din testbench și implementarea reală să folosească aceeași convenție de indexare (ex: `>=` vs `>`).

#### 3.1.4. Mod de rezolvare
S-a fixat o singură sursă de adevăr pentru parametrii de timing (aceleași `localparam`-uri folosite atât în testbench, cât și, ulterior, în DUT), eliminând ambiguitatea. Convenția aleasă: zona de sync e `[h_active+h_fp, h_active+h_fp+h_sync)`, cu limita inferioară inclusă și cea superioară exclusă.

---

### 3.2. Simulare

#### 3.2.1. Obiectiv
Verificarea funcțională a modulului `vga_driver` (numărători, generare sincronizări, generare culoare, comportament la reset) folosind testbench-ul `tb_vga_top`, înainte de a trece la implementare pe placă.

#### 3.2.2. Realizare
S-a scris modulul `vga_driver`:

- doi numărători sincroni pe `pix_clk` (`h_cnt`, `v_cnt`) care parcurg întreg cadrul;
- logică combinațională pentru zona activă (`active`), zona de hsync și zona de vsync, derivată direct din numărători;
- generarea `hsync`/`vsync` pe baza polarității configurate;
- generarea culorii: `image_red/green/blue` în zona activă, `0` în rest (blanking).

Testbench-ul rulează trei tipuri de verificări:
- verificare pixel-cu-pixel (comparație cu un model software al numărătorilor);
- verificare pe cadru complet (numărătoare agregate: pixeli activi, pixeli de blank, pixeli de hsync/vsync);
- test de reset la jumătate de cadru, urmat de verificare cadre complete după reset.

#### 3.2.3. Dificultăți
La prima rulare, testul de reset eșua cu eroarea `expected output zero during reset`, deși sincronizările ieșeau corect. Cauza: la `h_cnt=0, v_cnt=0` (starea imediat după reset), condiția de zonă activă (`h_cnt<h_active && v_cnt<v_active`) era adevărată, deci `vga_red/green/blue` ieșeau cu culoarea de test în loc de `0` — reset-ul numărătorilor nu era suficient pentru a garanta o ieșire de culoare "sigură", pentru că starea `(0,0)` cade chiar la începutul zonei active, nu în afara ei (spre deosebire de zonele de sync, care sunt la coordonate mari și nu sunt afectate).

#### 3.2.4. Mod de rezolvare
Condiționarea explicită a ieșirii de culoare și de starea `rst_n`, nu doar de `active`:

```systemverilog
assign vga_red   = (rst_n && active) ? image_red   : '0;
assign vga_green = (rst_n && active) ? image_green : '0;
assign vga_blue  = (rst_n && active) ? image_blue  : '0;
```

După corecție, testul complet a trecut: `vga test passed with 0 errors`, cu toate cele 4 cadre complete verificate după reset având valori identice și corecte (`active=307200`, `expected=307200`, `hsync=50400`, `vsync=1600`).

---

### 3.3. Implementare

#### 3.3.1. Obiectiv
Integrarea `vga_driver` într-un top-level de placă (`vga_top`), care generează ceasul de pixel din ceasul de sistem al plăcii (`clk_100MHz`) folosind un clocking wizard (`vga_ctrl_block_wrapper` → `vga_ctrl_block`, generat cu unealta Xilinx/Vivado), pregătit pentru sinteză și implementare pe FPGA.

#### 3.3.2. Realizare
S-a creat modulul `vga_top`, care:

- instanțiază `vga_ctrl_block_wrapper` pentru a genera `pix_clk` din `clk_100MHz`;
- preia semnalul de reset al plăcii (`btnC`, activ pe 1) și îl folosește atât pentru `reset_rtl_0` al clocking wizard-ului, cât și, inversat, ca `rst_n` (activ pe 0) pentru `vga_driver`;
- instanțiază `vga_driver`, conectând `pix_clk` și `rst_n`, și propagă ieșirile (`hsync`, `vsync`, `vga_red/green/blue`) către porturile de top.

S-au scris constrângerile (`.xdc`) pentru Basys 3: ceas pe `W5`, buton de reset (`btnC`) pe `U18`, semnalele VGA pe pinii standard ai conectorului de pe placă.

#### 3.3.3. Dificultăți
- `vga_ctrl_block_wrapper` nu expune un semnal `locked` al MMCM-ului: doar `clk_out1_0` și `reset_rtl_0`. Fără acest semnal, nu se poate garanta că `vga_driver` pornește abia după ce ceasul de pixel e stabil.
- Interfața de top (`clk_100MHz`, `btnC`) nu mai coincide cu interfața testată de `tb_vga_top` (`pix_clk`, `rst_n`), deci testbench-ul existent nu se mai poate lega direct de `vga_top`.
- La scrierea constrângerilor (`.xdc`), pornind de la template-ul master de la Digilent, liniile de `PACKAGE_PIN` au fost redenumite cu numele porturilor proprii (`vga_red`, `hsync`, `reset` etc.), dar liniile de `IOSTANDARD` de dedesubt au rămas cu numele vechi din template (`vgaRed`, `Hsync`, `btnC`). Rezultatul ar fi fost critical warnings la implementare ("port does not match any port in the current design") și erori DRC (`IOSTANDARD` nespecificat) la generarea bitstream-ului.
- **Bug de polaritate pe reset:** ieșirea `rst_n` a `vga_driver` a fost conectată inițial direct la semnalul de reset (activ pe 1), fără inversare. Rezultat: în funcționare normală (buton neapăsat), `vga_driver` rămânea permanent în reset, numărătorii `h_cnt`/`v_cnt` înghețau pe `0`, `hsync`/`vsync` nu mai făceau tranziții, iar monitorul nu primea semnal valid (afișa "no signal" în loc de imagine).
- S-a evaluat necesitatea unui sincronizator de reset (dublu flip-flop) pentru trecerea semnalului `reset` din domeniul `clk_100MHz` în domeniul `pix_clk`, ca protecție împotriva metastabilității.

#### 3.3.4. Mod de rezolvare
- Bug-ul de polaritate a fost corectat conectând `rst_n` la `~reset` în loc de `reset`, restabilind funcționarea normală în afara reset-ului.
- Sincronizatorul de reset a fost evaluat ca **neesențial** pentru acest proiect: reset-ul controlează doar doi numărători care rulează liber, fără stare persistentă; un eventual glitch de metastabilitate ar produce cel mult o pâlpâire imperceptibilă la un singur cadru, auto-corectată la cadrul următor (16.7ms mai târziu), nu o defecțiune persistentă. Sincronizatorul a fost eliminat din `vga_top` pentru simplitate, rămânând documentat ca opțiune de bună practică dacă cerințele proiectului cer rigoare suplimentară de tip CDC (clock domain crossing).
- Lipsa semnalului `locked` a fost documentată ca limitare cunoscută, cu recomandarea de a regenera IP-ul de clocking wizard cu opțiunea de `locked` activată, dacă apar probleme de stabilitate la pornire.
- Constrângerile au fost corectate astfel încât numele de port din liniile `IOSTANDARD` să fie identic cu cel din liniile `PACKAGE_PIN` corespunzătoare. Pinii fizici folosiți (clock pe `W5`, buton de reset pe `U18`, semnalele VGA pe `G19/H19/J19/N19` etc.) au fost verificați ca fiind corecți pentru placa Basys 3, contra fișierului master `.xdc` oficial de la Digilent.


**Utilizare resurse:**

| Resursă | Utilizare | Procent (%) |
|---|---|---|
| LUT | 27 | 0.13 |
| FF | 20 | 0.05 |
| IO | 17 | 16.04 |
| BUFG | 2 | 6.25 |
| MMCM | 1 | 20 |

**Timing closure:**

| Setup | Hold | Pulse Width |
|---|---|---|
| WNS = 36.426 ns | WHS = 0.063 ns | WPWS = 3.0 ns|

---

### 3.4. Extindere: LED de stare reset și culoare personalizată

#### 3.4.1. Obiectiv
Adăugarea unui LED pe placă care indică vizual starea de reset (aprins cât timp butonul e apăsat), și configurarea unei culori de test personalizate în locul culorii solide inițiale (roșu pur).

#### 3.4.2. Realizare
- S-a adăugat portul `rst_led` la `vga_top`, conectat direct la semnalul de reset: `assign rst_led = reset;`.
- S-a adăugat constrângerea pentru LED în `.xdc`, pe pinul `U16` (`LED[0]` pe Basys 3), verificat contra fișierului master `.xdc` oficial de la Digilent.
- S-a înlocuit culoarea implicită de test (`image_red=4'hF, image_green=4'h0, image_blue=4'h0` — roșu pur) cu o culoare personalizată, derivată dintr-un cod hex web `#00FFDA` (turcoaz).

#### 3.4.3. Dificultăți
Modulul folosește 4 biți per canal de culoare (`color_w=4`), adică doar 16 nivele posibile per canal, față de cele 256 dintr-un cod hex web standard (8 biți per canal). Conversia unui cod hex arbitrar la 4 biți nu poate fi exactă în general.

#### 3.4.4. Mod de rezolvare
Conversia s-a făcut prin trunchierea fiecărui canal de la 8 la 4 biți (`valoare_4bit = valoare_8bit >> 4`, echivalent cu împărțire la 16, rotunjită în jos):

- R: `0x00 >> 4 = 0x0`
- G: `0xFF >> 4 = 0xF`
- B: `0xDA (218) >> 4 = 0xD` (13)

```systemverilog
parameter logic [color_w-1:0] image_red   = 4'h0,
parameter logic [color_w-1:0] image_green = 4'hF,
parameter logic [color_w-1:0] image_blue  = 4'hD
```

Rezultatul afișat pe monitor corespunde culorii 8-bit `#00FFDD` (221 în loc de 218 pe canalul albastru) — o diferență de 3 unități față de codul original, invizibilă cu ochiul liber, dar de reținut ca limitare inerentă a rezoluției de 4 biți/canal (12-bit RGB total), nu o eroare de calcul.

---

### 3.5. Etape următoare (planificate)

#### 3.5.1. Obiectiv
Extinderea proiectului de la afișarea unei culori solide la afișarea unei forme geometrice pe monitor.

#### 3.5.2. Realizare
*(neînceput — decizie ce va fi luată ulterior, în funcție de constrângerile de la fața locului)*

#### 3.5.3. Dificultăți
*(de completat)*

#### 3.5.4. Mod de rezolvare
*(de completat)*
