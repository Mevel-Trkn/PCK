[bits 16]
[org 0x0000]

; os.asm: ana işletim sistemi runtime katmanı
; Burada bootloader yoktur. Bootloader tamamen bootloader.asm içinde olur.
; Bu katman sadece uygulama/masaüstü shell ve uygulama ikonu mantığına sahip olur.
; Ana akış: bootloader.asm -> os.bin -> desktop shell -> uygulamalar
; Uygulamalar: app_edit, trash_data, terminal, explorer, ...

; --------------------------------------------------
; RAM HARİTASI
; --------------------------------------------------
; 0x0000 - 0x7C00 : bootloader + low BIOS data
; 0x1000:0000     : kernel / OS yüklenecek alan
; 0x2000         : OS veri segmenti (DS/ES)
; 0x3000         : Desktop buffer / arka plan RAM
; 0x3100         : Dosya sistemi tablo alanı
; 0x4000         : Uygulama ve shell kod alanı
; 0xA000         : VGA VRAM
; 0xFFFE         : Stack üstü

RAM_SEGMENT equ 0x2000
DESKTOP_BUFFER equ 0x3000
FS_TABLE equ 0x3100
APP_AREA equ 0x4000
VIDEO_RAM equ 0xA000
STACK_TOP equ 0xFFFE

; --------------------------------------------------
; Minimal dosya sistemi (RAM tablosu)
; Dosyalar isim listesi olarak tutulur; bu katman bir desktop shell'i
; gerçekten "DOSYA TABANLI" hale getirir.
; --------------------------------------------------
; --------------------------------------------------
; DOSYA SİSTEMİ: P:\User\PCK\Desktop ve Downloads
; Klasörler ve dosyalar burada path olarak tanımlanır.
; --------------------------------------------------
fs_root_path db 'P:\User\PCK', 0
fs_desktop_path db 'P:\User\PCK\Desktop', 0
fs_downloads_path db 'P:\User\PCK\Downloads', 0
fs_trash_path db 'P:\User\PCK\Trash', 0

fs_entry_count db 3
fs_entries:
    db 'Desktop', 0
    db 'Downloads', 0
    db 'Trash', 0

fs_show_list:
    ; Dosya sistemi üzerinde mevcut klasörleri gösterir.
    mov si, fs_entries
    mov cl, [fs_entry_count]
    xor ch, ch

.fs_loop:
    cmp cl, 0
    je .done
    ; Burada isimler daha sonra ekranda gösterilebilir.
    ; Şimdilik sadece listede tutulurlar.
    ; Sonraki girişe geç
    xor al, al
    mov al, [si]
    cmp al, 0
    je .next_entry
    jmp .next_entry

.next_entry:
    ; 0 terminatorden sonra bir sonraki isim başlar
    inc si
    dec cl
    jnz .fs_loop

.done:
    ret

fs_find:
    ; Basit isim bulma: AL=1 bulundu, 0 bulunamadı.
    mov si, fs_entries
    mov cl, [fs_entry_count]
    xor ch, ch

.find_loop:
    cmp cl, 0
    je .not_found
    mov di, si
    mov bx, fs_name
    call strcmp
    cmp al, 1
    je .found

    ; sonraki isme geç
    xor al, al
    mov al, [si]
    cmp al, 0
    je .next_entry
    jmp .next_entry

.next_entry:
    inc si
    dec cl
    jnz .find_loop
    jmp .not_found

.found:
    mov al, 1
    ret

.not_found:
    xor al, al
    ret

strcmp:
    push si
    push di

.str_loop:
    mov al, [di]
    mov ah, [bx]
    cmp al, 0
    je .check_end
    cmp al, ah
    jne .not_equal
    inc di
    inc bx
    jmp .str_loop

.check_end:
    cmp ah, 0
    je .equal
    jmp .not_equal

.equal:
    mov al, 1
    pop di
    pop si
    ret

.not_equal:
    xor al, al
    pop di
    pop si
    ret

fs_name db 'Desktop', 0

basla:
    push ds
    push es

    mov ax, RAM_SEGMENT
    mov ds, ax
    mov es, ax

    ; Stack ayarlama
    mov ax, 0
    mov ss, ax
    mov sp, STACK_TOP

    ; Desktop buffer ve dosya sistemi işaretçileri
    mov ax, DESKTOP_BUFFER
    mov [desktop_base], ax
    mov ax, FS_TABLE
    mov [fs_base], ax

    mov ax, 0x0013
    int 0x10

    mov ax, VIDEO_RAM
    mov es, ax

    mov byte [menu_acik], 0
    mov word [cursor_x], 20
    mov word [cursor_y], 20
    call masaustu_ciz

.tus_bekle:
    mov ah, 0x01
    int 0x16
    jz .tus_bekle

    xor ah, ah
    int 0x16

    cmp al, 27
    je .cikis
    cmp al, 'm'
    je .menu_degis
    cmp al, 'M'
    je .menu_degis

    jmp .tus_bekle

.menu_degis:
    xor byte [menu_acik], 1
    call masaustu_ciz
    jmp .tus_bekle

.cikis:
    mov ax, 0x0003
    int 0x10
    pop es
    pop ds
    retf

; --------------------------------------------------
; Basit dikdörtgen çizici
; Girdi: AX=x, BX=y, CX=w, DX=h, AL=renk
; --------------------------------------------------
cevre_ciz:
    push si
    push di

    mov si, ax
    mov di, bx

.y_dongusu:
    mov ax, 320
    mul di
    add ax, si
    mov di, ax

    mov cx, cx
    ; cx = genişlik; di = başlama adresi
    ; her satır için aynı genişlik boyunca renk yaz
.x_dongusu:
    mov byte [es:di], al
    inc di
    loop .x_dongusu

    inc bx
    dec dx
    jnz .y_dongusu

    pop di
    pop si
    ret

masaustu_ciz:
    ; Arka plan: cyan
    mov ax, 0
    mov bx, 0
    mov cx, 320
    mov dx, 200
    mov al, 11
    call cevre_ciz

    ; Üst başlık / başlık etiketi
    mov ax, 5
    mov bx, 5
    mov cx, 120
    mov dx, 10
    mov al, 9
    call cevre_ciz

    ; Saat / sistem etiketi (kısa ve sabit)
    mov ax, 220
    mov bx, 5
    mov cx, 80
    mov dx, 10
    mov al, 9
    call cevre_ciz

    ; Görev çubuğu
    mov ax, 0
    mov bx, 180
    mov cx, 320
    mov dx, 20
    mov al, 8
    call cevre_ciz

    ; Başlat butonu
    mov ax, 0
    mov bx, 185
    mov cx, 40
    mov dx, 15
    mov al, 2
    call cevre_ciz

    ; Kısa uygulama simgesi: masaüstünde 3 tane ikon
    mov ax, 25
    mov bx, 30
    mov cx, 24
    mov dx, 24
    mov al, 7
    call cevre_ciz

    mov ax, 120
    mov bx, 30
    mov cx, 24
    mov dx, 24
    mov al, 7
    call cevre_ciz

    mov ax, 215
    mov bx, 30
    mov cx, 24
    mov dx, 24
    mov al, 7
    call cevre_ciz

    ; Başlat menüsü: alt sol köşede, taskbarın üstüne açılır
    cmp byte [menu_acik], 1
    jne .bitir

    mov ax, 0
    mov bx, 120
    mov cx, 120
    mov dx, 60
    mov al, 7
    call cevre_ciz

    mov ax, 8
    mov bx, 132
    mov cx, 90
    mov dx, 10
    mov al, 8
    call cevre_ciz

    mov ax, 8
    mov bx, 148
    mov cx, 90
    mov dx, 10
    mov al, 8
    call cevre_ciz

.bitir:
    ret

cursor_x dw 20
cursor_y dw 20
menu_acik db 0
pck_desktop db 'PCKDesktop...', 0
desktop_base dw DESKTOP_BUFFER
fs_base dw FS_TABLE

; OS payload is not a boot sector; do not force 512-byte padding.
; The bootloader loads the OS image from disk separately.