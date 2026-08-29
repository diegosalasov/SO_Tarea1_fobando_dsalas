; Print extension for extra functionalities via interrupts
; Requires <print.asm> to use base print functions
; -----------------------------------------------------------

; Print a decimal number in AX to the screen
; print_d(value)
; @params:
; AX => value
print_d:
    ;start
    mov bx, 10  ; Base 10
    xor cx, cx  ; Clear CX (digit count)
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
    ;save registers
    push dx
    push cx
    ;call func
    call print_c; Print character in AL
    ;restore registers
    pop cx
    pop dx
    ;continue
    dec cx      ; Decrement digit count
    cmp cx, 0   ; Check if all digits printed
    jnz .print_digits ; If not zero, continue printing
.done:
    ;end
    ret

; Print a null terminated string pointed to by SI (with pattern recognition)
; parameters are pushed to the stack from right to left
; NOTE: recognizes patterns like \t, \n, %d, \\
; printf(string, params)
; @params:
; SI => pointer to start of string
; @example: 
; str db "Values: [%d][%d]\n", 0
; printf(str,47,83) => SI=str, push(83), push(47)
printf:
    ;clean registers
    xor cx, cx
    ;start
    cld
    lodsb       ; Load byte (char) from [DS:SI] into AL, increment SI (1st)
    mov cl, al
    ; > Pre-check for null terminator (0)
    cmp cl, 0   ; (0)
    je .printf_done
.printf_loop:
    mov ch, cl  ; move prev char to CH
    lodsb       ; Load byte (char) from [DS:SI] into AL, increment SI
    mov cl, al  ; move next char to CL
    ; > Check for number pattern (%d)
    .printf_numtype:
    cmp cx, 0x2564 ; (%)(d) = (0x25)(0x64)
    jne .printf_crlf
    pop bx  ; pop return address
    pop ax  ; pop value
    push bx ; push return address
    push cx ; save CX
    call print_d
    pop cx  ; restore CX
    jmp .printf_cyclen
    ; > Check for newline (CRLF) pattern (\n)
    .printf_crlf:
    cmp cx, 0x5C6E ; (\)(n) = (0x5C)(0x6E)
    jne .printf_tab
    push cx ; save CX
    call print_newline
    pop cx  ; restore CX
    jmp .printf_cyclen
    ; > Check for tab pattern (\t)
    .printf_tab:
    cmp cx, 0x5C74 ; (\)(t) = (0x5C)(0x74)
    jne .printf_bslash
    push cx ; save CX
    call print_tab
    pop cx  ; restore CX
    jmp .printf_cyclen
    ; > Check for backslash pattern (\\)
    .printf_bslash:
    cmp cx, 0x5C5C ; (\)(\) = (0x5C)(0x5C)
    jne .printf_continue
    push cx ; save CX
    call print_backslash
    pop cx  ; restore CX
    ; > On pattern match, cycle next char
    .printf_cyclen:
    lodsb       ; Load byte (char) from [DS:SI] into AL, increment SI
    mov cl, al  ; move NEW char to CL
    jmp .printf_null
    ; > ASCII char printing
    .printf_continue:
    mov al, ch
    push cx
    call print_c
    pop cx
    ; > Check for null-terminator (0)
    .printf_null:
    cmp cl, 0       ; (0)
    je .printf_done ; break
    jmp .printf_loop; next iter
.printf_done:
    ;end
    ret

; Print a newline (CRLF) subroutine
print_newline:
    mov al, 0x0D    ; carriage return (CR)
    call print_c
    mov al, 0x0A    ; line feed (LF)
    call print_c
    ret

; Print a tab subroutine
print_tab:
    mov al, 0x09    ; tab
    call print_c
    ret

; Print a backslash subroutine
print_backslash:
    mov al, 0x5C    ; \
    call print_c
    ret