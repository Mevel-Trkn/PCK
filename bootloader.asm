[bits 16]
[org 0x7c00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; OS'i diskten RAM'e yükle
    ; ES:BX = 0x1000:0x0000
    mov ax, 0x1000
    mov es, ax
    xor bx, bx

    mov ah, 0x02
    mov al, 32
    mov ch, 0
    mov dh, 0
    mov cl, 2
    int 0x13
    jc disk_hatasi

    ; OS'e geç
    jmp 0x1000:0x0000

disk_hatasi:
    mov ah, 0x0E
    mov al, 'E'
    int 0x10
    jmp $

times 510-($-$$) db 0
dw 0xAA55
