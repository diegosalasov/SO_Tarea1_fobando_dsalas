[BITS 16]       ; 16 bit mode
[ORG 0x7C00]    ; Set the origin to 0x7C00, where the BIOS loads the bootloader

; Bootloader code
start:
    ; Here starts the bootloader

    ; Print a message to the screen
    mov si, message
    call printf

    ; End of bootloader code (loop forever)
    jmp $

message db "Hello from my bootloader!", 0

%include "src/legacy/utils/print.asm"
;%include "src/legacy/utils/disk_read.asm"

times 510-($-$$) db 0
dw 0xAA55