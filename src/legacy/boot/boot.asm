[BITS 16]       ; 16 bit mode
[ORG 0x7C00]    ; Set the origin to 0x7C00, where the BIOS loads the bootloader

; Bootloader setup
clock equ 0x7E00

; Bootloader code (512 bytes)
start:
    ; Here starts the bootloader
    xor ax, ax        ; Clear AX
    xor bx, bx        ; Clear BX
    xor cx, cx        ; Clear CX
    xor dx, dx        ; Clear DX
    xor si, si        ; Clear SI

    ; Print a message to the screen
    mov si, message
    call print_s

    ; Load a new disk sector to RAM (app.asm)
    mov ax, 0x0000
    mov es, ax          ; Destination Segment ES=0x0000
    mov bx, clock       ; Destination Offset  BX=0x7E00
    mov al, 0x01        ; Read 1
    mov dl, 0x80        ; Drive 0
    mov ch, 0x00        ; Cylinder 0
    mov dh, 0x00        ; Head 0
    mov cl, 0x02        ; Sector 2
    call disk_read

    ; Program handoff
    call clock

    ; End of bootloader code (loop forever)
    jmp $

; Bootloader data
message db "Bootloader running...", 0x0D, 0x0A, 0

; Bootloader utilities
%include "src/legacy/utils/print.asm"
%include "src/legacy/utils/disk_read.asm"

; Fill the rest of the 512 bytes with zeros and add the boot signature
times 510-($-$$) db 0 ; padding
dw 0xAA55             ; boot signature