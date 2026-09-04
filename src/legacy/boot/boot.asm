[BITS 16]
[ORG 0x7C00]

%ifndef APP_SECTORS
    %error "APP_SECTORS debe calcularse a partir de app.bin"
%endif

; Normalizar CS:IP porque distintas BIOS pueden entrar como
; 0000:7C00 o 07C0:0000.
jmp 0x0000:start

start:
    cli

    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    sti
    cld

    ; La BIOS entrega en DL la unidad desde la que arranco.
    mov [boot_drive], dl

    mov si, message
    call printf

    ; Cargar la aplicacion desde el sector 2 en 0000:7E00.
    xor ax, ax
    mov es, ax
    mov bx, APP_LOAD_ADDRESS

    mov dl, [boot_drive]
    mov ch, 0x00
    mov cl, 0x02
    mov dh, 0x00
    mov al, APP_SECTORS

    call read_sector

    ; Transferir el control con CS normalizado a cero.
    jmp 0x0000:APP_LOAD_ADDRESS

APP_LOAD_ADDRESS equ 0x7E00

boot_drive:
    db 0

message:
    db "Bootloader running...", 0

; Bootloader utilities
%include "src/legacy/utils/print.asm"
%include "src/legacy/utils/disk_read.asm"

; Completar el sector y agregar la firma de arranque.
times 510-($-$$) db 0
dw 0xAA55
