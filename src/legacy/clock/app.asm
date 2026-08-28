[BITS 16]
[ORG 0x7E00]

; Simple program that makes an interative loop sum and prints a message to the screen
app:
    ; Print a message to the screen
    mov si, app_msg
    call printf
    ; Define parameters
    mov ax, 0   ; value/result
    mov cx, 0   ; counter
    .iter_loop:
        add ax, cx   ; ax += ax
        inc cx       ; cx += 1
        cmp cx, 16   ; cx == 10
        je  .iter_done ; break
        jmp .iter_loop
    .iter_done:
        ; Print result
        push ax
        mov si, res_msg
        call printf
        pop ax
        call printn
        ; end
        ret

app_msg db "Calling app(iterative_sum)...", 0
res_msg db "Result: ", 0

; Progam includes
%include 'src/legacy/utils/print.asm'

; Fill the rest of the 512 bytes with zeros
times 512-($-$$) db 0 ; padding