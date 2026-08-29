; Simple print functionalities for bootloader via interrupts
; ------------------------------------------------------------------

; Print a character in AL to the screen using BIOS interrupt 0x10
; print_c(char)
; @params:
; AL => char
print_c:
    ;start
    mov ah, 0x0E    ; Teletype function
    mov bh, 0x00    ; Display page 0
    mov bl, 0x07    ; White on black color
    int 0x10        ; interrupt: video services
    ;end
    ret

; Print a null-terminated string pointed to by SI (no pattern recognition)
; print_s(string)
; @params:
; SI => pointer to start of string
print_s:
    ;start
.print_s_loop:
    lodsb             ; Load byte from [DS:SI] into AL, increment SI
    ; > Check for null-terminator (0)
    cmp al, 0         ; '0'
    je .print_s_done
    ; > ASCII char printing
    call print_c      ; Print the character in AL
    jmp .print_s_loop
.print_s_done:
    ;end
    ret
