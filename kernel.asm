[bits 16]
[org 0x0000]        

ana_merkez:
    mov ax, 0x1000
    mov ds, ax
    mov es, ax

    mov ax, 0x0003
    int 0x10

    ; PS/2 controller init is deferred. Initial boot must not hang on a missing
    ; or still-initializing keyboard/mouse controller before the shell is shown.
    ; BIOS keyboard path (INT 16h) is enough for the early command prompt.

    mov si, baslik
    call yazdir

komut_dongusu:
    mov si, prompt
    call yazdir_yesil

    call komut_oku
    call komut_isle
    jmp komut_dongusu

yazdir:
    mov ah, 0x0E
.dongu:
    lodsb
    cmp al, 0
    je .tamam
    int 0x10
    jmp .dongu
.tamam:
    ret

yazdir_yesil:
    mov ah, 0x0E
    mov si, prompt
.dongu:
    lodsb
    cmp al, 0
    je .tamam
    int 0x10
    jmp .dongu
.tamam:
    ret

ps2_wait_controller:
    mov dx, 0x64
.wait:
    in al, dx
    test al, 2
    jnz .wait
    ret

ps2_wait_data:
    mov dx, 0x64
.wait:
    in al, dx
    test al, 1
    jz .wait
    ret

ps2_init:
    ; Minimal PS/2 init is intentionally kept isolated from the boot path.
    ; If the controller is absent or busy, the old code could loop forever and
    ; freeze the system before the command prompt appears.
    mov dx, 0x64
.flush:
    in al, dx
    test al, 1
    jz .ready
    in al, 0x60
    jmp .flush
.ready:
    mov al, 0xAD
    out 0x64, al
    call ps2_wait_controller
    mov al, 0xAE
    out 0x64, al
    call ps2_wait_controller
    mov al, 0xF4
    out 0x60, al
    ret

ps2_mouse_wait_data:
    mov dx, 0x64
.wait:
    in al, dx
    test al, 1
    jz .wait
    ret

ps2_mouse_wait_write:
    mov dx, 0x64
.wait:
    in al, dx
    test al, 2
    jnz .wait
    ret

ps2_mouse_init:
    ; Sadece masaüstü modunda başlat. Komut satırı bozulmasın.
    mov al, 0xA8
    out 0x64, al

    mov al, 0xD4
    out 0x64, al
    mov al, 0xF6
    out 0x60, al
    call ps2_mouse_wait_data
    in al, 0x60

    mov al, 0xD4
    out 0x64, al
    mov al, 0xF4
    out 0x60, al
    call ps2_mouse_wait_data
    in al, 0x60
    ret

ps2_mouse_read_packet:
    ; 3 baytlık PS/2 mouse paketini okur. ACK/AA paketlerini atla.
    mov dx, 0x64

.wait_status:
    in al, dx
    test al, 1
    jz .wait_status
    in al, 0x60
    mov bx, mouse_status
    mov [bx], al
    cmp al, 0xFA
    je .done
    cmp al, 0xAA
    je .done
    ; hareket paketinde bit 3 (0x08) olmalıdır
    test al, 0x08
    jz .done

.wait_dx:
    in al, dx
    test al, 1
    jz .done
    in al, 0x60
    mov bx, mouse_dx
    mov [bx], al

.wait_dy:
    in al, dx
    test al, 1
    jz .done
    in al, 0x60
    mov bx, mouse_dy
    mov [bx], al
    ret

.done:
    ret

mouse_update_cursor:
    ; Mouse hareketini cursor koordinatına uygula.
    mov bx, mouse_dx
    movsx ax, byte [bx]
    mov bx, cursor_x
    add word [bx], ax
    cmp word [bx], 0
    jl .min_x
    cmp word [bx], 319
    jle .y_update
.max_x:
    mov word [bx], 319
    jmp .y_update
.min_x:
    mov word [bx], 0

.y_update:
    mov bx, mouse_dy
    movsx ax, byte [bx]
    neg ax
    mov bx, cursor_y
    add word [bx], ax
    cmp word [bx], 0
    jl .min_y
    cmp word [bx], 199
    jle .done
.max_y:
    mov word [bx], 199
    ret
.min_y:
    mov word [bx], 0
.done:
    ret

ps2_read_key:
    call ps2_wait_data
    in al, 0x60
    mov ah, al

    ; Make / break kodlarını yoksay
    cmp al, 0xE0
    je .skip_extended
    cmp al, 0xF0
    je .skip_release
    jmp .map

.skip_extended:
    call ps2_wait_data
    in al, 0x60
    mov ah, al
    cmp al, 0xF0
    je .skip_release
    jmp .map

.skip_release:
    call ps2_wait_data
    in al, 0x60
    mov ah, al

.map:
    cmp al, 0x1C
    je .enter
    cmp al, 0x0E
    je .backspace
    cmp al, 0x01
    je .escape
    cmp al, 0x39
    je .space
    cmp al, 0x48
    je .up
    cmp al, 0x50
    je .down
    cmp al, 0x4B
    je .left
    cmp al, 0x4D
    je .right

    ; Rakamlar
    cmp al, 0x02
    je .k1
    cmp al, 0x03
    je .k2
    cmp al, 0x04
    je .k3
    cmp al, 0x05
    je .k4
    cmp al, 0x06
    je .k5
    cmp al, 0x07
    je .k6
    cmp al, 0x08
    je .k7
    cmp al, 0x09
    je .k8
    cmp al, 0x0A
    je .k9
    cmp al, 0x0B
    je .k0

    ; Harfler (QWERTY)
    cmp al, 0x1E
    je .a
    cmp al, 0x30
    je .b
    cmp al, 0x2E
    je .c
    cmp al, 0x20
    je .d
    cmp al, 0x12
    je .e
    cmp al, 0x21
    je .f
    cmp al, 0x22
    je .g
    cmp al, 0x23
    je .h
    cmp al, 0x17
    je .i
    cmp al, 0x24
    je .j
    cmp al, 0x25
    je .k
    cmp al, 0x26
    je .l
    cmp al, 0x32
    je .m
    cmp al, 0x31
    je .n
    cmp al, 0x18
    je .o
    cmp al, 0x19
    je .p
    cmp al, 0x10
    je .q
    cmp al, 0x13
    je .r
    cmp al, 0x1F
    je .s
    cmp al, 0x14
    je .t
    cmp al, 0x16
    je .u
    cmp al, 0x2F
    je .v
    cmp al, 0x11
    je .w
    cmp al, 0x2D
    je .x
    cmp al, 0x15
    je .y
    cmp al, 0x2C
    je .z

    mov al, 0
    ret

.enter:      mov al, 13
    ret
.backspace:  mov al, 8
    ret
.escape:     mov al, 27
    ret
.space:      mov al, ' '
    ret
.up:         mov al, 0
    ret
.down:       mov al, 0
    ret
.left:       mov al, 0
    ret
.right:      mov al, 0
    ret
.k1:         mov al, '1'
    ret
.k2:         mov al, '2'
    ret
.k3:         mov al, '3'
    ret
.k4:         mov al, '4'
    ret
.k5:         mov al, '5'
    ret
.k6:         mov al, '6'
    ret
.k7:         mov al, '7'
    ret
.k8:         mov al, '8'
    ret
.k9:         mov al, '9'
    ret
.k0:         mov al, '0'
    ret
.a:          mov al, 'a'
    ret
.b:          mov al, 'b'
    ret
.c:          mov al, 'c'
    ret
.d:          mov al, 'd'
    ret
.e:          mov al, 'e'
    ret
.f:          mov al, 'f'
    ret
.g:          mov al, 'g'
    ret
.h:          mov al, 'h'
    ret
.i:          mov al, 'i'
    ret
.j:          mov al, 'j'
    ret
.k:          mov al, 'k'
    ret
.l:          mov al, 'l'
    ret
.m:          mov al, 'm'
    ret
.n:          mov al, 'n'
    ret
.o:          mov al, 'o'
    ret
.p:          mov al, 'p'
    ret
.q:          mov al, 'q'
    ret
.r:          mov al, 'r'
    ret
.s:          mov al, 's'
    ret
.t:          mov al, 't'
    ret
.u:          mov al, 'u'
    ret
.v:          mov al, 'v'
    ret
.w:          mov al, 'w'
    ret
.x:          mov al, 'x'
    ret
.y:          mov al, 'y'
    ret
.z:          mov al, 'z'
    ret

komut_oku:
    mov di, girdi_tamponu
.tus_bekle:
    ; Komut satırı için BIOS klavye yolunu koru; PS/2 fonksiyonları
    ; arayüzde hazır kalsın ama ilk ekran bozulmasın.
    mov ah, 0x00
    int 0x16

    cmp al, 13
    je .bitti
    cmp al, 8
    je .sil

    cmp byte [layout_mode], 1
    jne .ekrana_bas
    call tr_klavye_cevir

.ekrana_bas:
    mov ah, 0x0E
    int 0x10
    stosb
    jmp .tus_bekle

.sil:
    cmp di, girdi_tamponu
    je .tus_bekle
    dec di
    mov ah, 0x0E
    mov al, 8
    int 0x10
    mov al, ' '
    int 0x10
    mov al, 8
    int 0x10
    jmp .tus_bekle

.bitti:
    mov byte [di], 0    
    mov ah, 0x0E
    mov al, 13
    int 0x10
    mov al, 10
    int 0x10
    ret

tr_klavye_cevir:
    cmp al, '['
    je .tr_g
    cmp al, ']'
    je .tr_u
    cmp al, ';'
    je .tr_s
    cmp al, 39
    je .tr_i
    cmp al, ','
    je .tr_o
    cmp al, '.'
    je .tr_c
    cmp al, '/'
    je .tr_nokta
    ret
.tr_g:  mov al, 'g'   
        ret
.tr_u:  mov al, 0x81  
        ret
.tr_s:  mov al, 's'   
        ret
.tr_i:  mov al, 'i'   
        ret
.tr_o:  mov al, 0x94  
        ret
.tr_c:  mov al, 0x87  
        ret
.tr_nokta: mov al, '.' 
        ret

komut_isle:
    mov si, girdi_tamponu
    mov di, cmd_help
    call string_karsilastir
    jc .calistir_help

    mov si, girdi_tamponu
    mov di, cmd_restart
    call string_karsilastir
    jc .calistir_restart

    mov si, girdi_tamponu
    mov di, cmd_shutdown
    call string_karsilastir
    jc .calistir_shutdown

    mov si, girdi_tamponu
    mov di, cmd_edit
    call string_karsilastir
    jc .calistir_edit

    mov si, girdi_tamponu
    mov di, cmd_desktop
    call string_karsilastir
    jc .calistir_desktop

    mov si, girdi_tamponu
    mov di, cmd_tr
    call string_karsilastir
    jc .calistir_tr

    mov si, girdi_tamponu
    mov di, cmd_en
    call string_karsilastir
    jc .calistir_en

    mov si, hata_mesaji
    call yazdir
    ret

.calistir_help:
    mov si, help_metni
    call yazdir
    ret

.calistir_restart:
    db 0xEA
    dw 0x0000
    dw 0xFFFF

.calistir_shutdown:
    mov ax, 0x5307
    mov bx, 0x0001
    mov cx, 0x0003
    int 0x15
    ret

.calistir_edit:
    mov ax, 0x2000
    mov es, ax
    xor bx, bx
    mov ah, 0x02
    mov al, 1
    mov ch, 0
    mov dh, 0
    mov cl, 6
    mov dl, 0
    int 0x13
    jc .uygulama_hata
    call 0x2000:0x0000
    mov ax, 0x0003
    int 0x10
    ret

.uygulama_hata:
    mov si, disk_hata_mesaji
    call yazdir
    ret

; ==================================================
; MASAÜSTÜ GRAFİK VE KLAVYE İMLEÇ MOTORU (Alpha 1.0)
; ==================================================
.calistir_desktop:
    mov ax, 0x0013      ; VGA Mod 13h (320x200 256 Renk)
    int 0x10
    call ps2_mouse_init
    mov ax, 0xA000      ; VRAM (Video RAM) Başlangıcı
    mov es, ax

    ; İmleci ekranın ortasına sıfırla
    mov bx, cursor_x
    mov word [bx], 160
    mov bx, cursor_y
    mov word [bx], 100
    mov bx, menu_acik
    mov byte [bx], 0

.masaustu_ciz:
    ; 1. Masaüstü arkaplanı: Windows benzeri işlevsel bir arka plan
    xor di, di
    mov al, 3
    mov cx, 64000
    rep stosb

    ; 2. Masaüstü simgeleri (sol üstte birkaç klasör/ikon bloğu)
    mov bx, 20
.icon_loop:
    mov ax, 320
    mul bx
    add ax, 12
    mov di, ax
    mov cx, 16
    mov al, 12
    rep stosb
    add bx, 28
    cmp bx, 120
    jl .icon_loop

    ; 3. Görev çubuğu (alt kısım)
    mov bx, 170
.taskbar_satir:
    mov ax, 320
    mul bx
    mov di, ax
    mov cx, 320
    mov al, 7
    rep stosb
    inc bx
    cmp bx, 200
    jl .taskbar_satir

    ; 4. Başlat butonu (sol altında, yeşil kare)
    mov bx, 170
.baslat_satir:
    mov ax, 320
    mul bx
    add ax, 0
    mov di, ax
    mov cx, 40
    mov al, 2
    rep stosb
    inc bx
    cmp bx, 200
    jl .baslat_satir

    ; 5. Başlat menüsü açılırsa alt menü paneli çiz
    mov bx, menu_acik
    cmp byte [bx], 1
    jne .imlec_ciz

    ; menu paneli: x=0..110, y=120..170
    mov bx, 120
.menu_satir:
    mov ax, 320
    mul bx
    add ax, 0
    mov di, ax
    mov cx, 110
    mov al, 8
    rep stosb
    inc bx
    cmp bx, 170
    jl .menu_satir

    ; menü başlık çizgisi
    mov bx, 120
.menu_baslik:
    mov ax, 320
    mul bx
    add ax, 0
    mov di, ax
    mov cx, 110
    mov al, 9
    rep stosb
    inc bx
    cmp bx, 122
    jl .menu_baslik

.imlec_ciz:
    ; 5. SENİN ÖZEL İMLECİNİ ÇİZ (8x8 Texture Kullanarak)
    mov bx, [cursor_y]
    mov cx, 8               ; İmleç 8 satır yüksekliğinde
    mov si, cursor_texture  ; Dokumuzun (Texture) hafızadaki adresi

.imlec_satir:
    push cx                 ; Satır döngüsünü kaybetmemek için hafızaya at
    
    ; Ekranda yazılacak VRAM adresini hesapla (Y * 320 + X)
    mov ax, 320
    mul bx
    add ax, [cursor_x]
    mov di, ax
    
    mov cx, 8               ; Her satırda 8 piksel (sütun) var

.imlec_piksel:
    lodsb                   ; Dokudan 1 piksel (1 bayt) oku (AL içine alır)
    cmp al, 255             ; Piksel şeffaf mı (255) ?
    je .piksel_atla         ; Şeffafsa ekrana çizme, atla!
    
    mov byte [es:di], al    ; Şeffaf değilse (Siyah veya Beyazsa) VRAM'e (ekrana) boya!

.piksel_atla:
    inc di                  ; Ekranda sağdaki piksele geç
    loop .imlec_piksel      ; Sütun bitene kadar devam et
    
    pop cx                  ; Satır döngüsünü geri al
    inc bx                  ; Ekranda bir alt satıra in
    loop .imlec_satir       ; 8 satır bitene kadar devam et

.tus_bekle_desktop:
    ; Mouse hareketini kontrol et
    mov dx, 0x64
    in al, dx
    test al, 1
    jz .keyboard_check
    call ps2_mouse_read_packet
    call mouse_update_cursor
    jmp .masaustu_ciz

.keyboard_check:
    mov ah, 0x01
    int 0x16
    jz .tus_bekle_desktop

    mov ah, 0x00
    int 0x16

    cmp al, 27          ; ESC'ye basıldıysa çık
    je .desktop_cikis

    cmp al, 13          ; ENTER tuşuna basıldıysa TIKLA!
    je .tiklama_kontrol

    ; Klavye Yön Tuşları (Scancode AH üzerinden okunur)
    cmp ah, 0x48        ; Yukarı Ok
    je .yukari
    cmp ah, 0x50        ; Aşağı Ok
    je .asagi
    cmp ah, 0x4B        ; Sol Ok
    je .sol
    cmp ah, 0x4D        ; Sağ Ok
    je .sag

    jmp .tus_bekle_desktop

.yukari:
    mov bx, cursor_y
    cmp word [bx], 5
    jle .masaustu_ciz
    sub word [bx], 5
    jmp .masaustu_ciz

.asagi:
    mov bx, cursor_y
    cmp word [bx], 188
    jge .masaustu_ciz
    add word [bx], 5
    jmp .masaustu_ciz

.sol:
    mov bx, cursor_x
    cmp word [bx], 5
    jle .masaustu_ciz
    sub word [bx], 5
    jmp .masaustu_ciz

.sag:
    mov bx, cursor_x
    cmp word [bx], 305
    jge .masaustu_ciz
    add word [bx], 5
    jmp .masaustu_ciz

.tiklama_kontrol:
    ; Başlat butonu: x=0..40, y=170..199
    mov bx, cursor_x
    cmp word [bx], 40
    jg .masaustuna_tikladi
    mov bx, cursor_y
    cmp word [bx], 170
    jl .masaustuna_tikladi
    cmp word [bx], 199
    jg .masaustuna_tikladi

    ; Başlat butonuna tam isabet! Menüyü Aç/Kapat
    mov bx, menu_acik
    xor byte [bx], 1
    jmp .masaustu_ciz

.masaustuna_tikladi:
    ; Menü dışında tıklanırsa kapat
    mov bx, menu_acik
    mov byte [bx], 0
    jmp .masaustu_ciz

.desktop_cikis:
    ; Masaüstünden çıkıp metin moduna dön
    mov ax, 0x0003
    int 0x10
    mov ax, 1000h
    mov es, ax
    ret
; ==================================================

.calistir_tr:
    mov byte [layout_mode], 1
    mov si, tr_mesaj
    call yazdir
    ret

.calistir_en:
    mov byte [layout_mode], 0
    mov si, en_mesaj
    call yazdir
    ret

string_karsilastir:
    push si
    push di
.dongu:
    mov al, [si]
    mov bl, [di]
    cmp al, bl
    jne .farkli
    cmp al, 0
    je .ayni
    inc si
    inc di
    jmp .dongu
.farkli:
    clc
    pop di
    pop si
    ret
.ayni:
    stc
    pop di
    pop si
    ret

baslik       db 'Plowix OS Alpha 1.0 active.', 13, 10, 'Type "help" for available commands.', 13, 10, 0
prompt       db 'Plowix OS> ', 0
hata_mesaji  db 'Unknown command!', 13, 10, 0

cmd_help     db 'help', 0
cmd_restart  db 'restart', 0
cmd_shutdown db 'shutdown', 0
cmd_edit     db 'edit', 0
cmd_desktop  db 'desktop', 0
cmd_tr       db 'tr', 0
cmd_en       db 'en', 0

help_metni   db 'Commands: help, restart, shutdown, edit, desktop, tr, en', 13, 10, 0
tr_mesaj     db 'TR Keyboard Layout activated.', 13, 10, 0
en_mesaj     db 'EN Keyboard Layout activated.', 13, 10, 0
disk_hata_mesaji db 'Uygulama diskten okunamadi!', 13, 10, 0

layout_mode  db 0        
girdi_tamponu times 32 db 0

; Wallpaper kaldırıldı; boot-safe desktop için tek renk arka plan kullanılacak.

; PS/2 Mouse değişkenleri
mouse_status db 0
mouse_dx db 0
mouse_dy db 0

; Masaüstü Değişkenleri
cursor_x dw 160
cursor_y dw 100
menu_acik db 0

; --- SENİN ÖZEL FARE İMLECİN (PYTHON'DAN ÜRETİLDİ) ---
cursor_texture:
    db 255, 0, 0, 0, 0, 255, 255, 255
    db 0, 15, 15, 15, 15, 0, 255, 255
    db 0, 15, 15, 15, 0, 255, 255, 255
    db 0, 15, 15, 15, 0, 255, 255, 255
    db 0, 15, 0, 0, 15, 0, 255, 255
    db 255, 0, 255, 255, 0, 15, 0, 255
    db 255, 255, 255, 255, 255, 0, 0, 255
    db 255, 255, 255, 255, 255, 255, 255, 255

; Real-mode boot için küçük tut: kernel 64 KiB sınırında kalmalı.
; wallpaper_data incbin kaldırıldı; yeniden eklemek için ayrı yükleme gerekir.
