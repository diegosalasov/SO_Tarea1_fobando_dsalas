; Simple print function for bootloader via interrupts

; Print a character in AL to the screen using BIOS interrupt 0x10
printc:
    mov ah, 0x0E    ; Teletype function
    mov bh, 0x00    ; Display page 0
    mov bl, 0x07    ; White on black color
    int 0x10
    ret

; Print a number in AX as decimal to the screen
printn:
    mov bx, 10      ; Base 10
    xor cx, cx      ; Clear CX (digit count)
    .div_loop:
        xor dx, dx  ; Clear DX for division
        div bx      ; Divide AX by 10, quotient in AX, remainder in DX
        push dx     ; Push remainder (digit) onto stack
        inc cx      ; Increment digit count
        cmp ax, 0   ; Check if quotient is zero
        jne .div_loop ; If not zero, continue dividing
    .print_digits:
        pop dx      ; Pop digit from stack
        add dl, '0' ; Convert to ASCII
        mov al, dl  ; Move to AL for printing
        call printc ; Print character
        dec cx      ; Decrement digit count
        cmp cx, 0   ; Check if all digits printed
        jnz .print_digits ; If not zero, continue printing
    .done:
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
