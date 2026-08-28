; Simple print function for bootloader via interrupts

; Print a character in AL to the screen using BIOS interrupt 0x10
printc:
    mov ah, 0x0E    ; Teletype function
    mov bh, 0x00    ; Display page 0
    mov bl, 0x07    ; White on black color
    int 0x10
    ret

; Print a null-terminated string pointed to by SI
printf:
.print_loop:
    lodsb           ; Load byte from [DS:SI] into AL, increment SI
    cmp al, 0       ; Check for null-terminator (0)
    je .done
    call printc      ; Print the character in AL
    jmp .print_loop
.done:
    ret