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
        cmp cx, 20    ; cx == 10
        je .iter_done ; break
        inc cx        ; cx += 1
        add ax, cx    ; ax += cx
        jmp .iter_loop
    .iter_done:
        ; Print result
        mov dx, ax
        push dx
        mov dx, cx
        push dx
        mov si, res_msg
        call printf
        ; end
        ret

app_msg db "Running program...\n\n", 0
res_msg db "\t [iterations: %d]\\[result: %d] \n", 0

; Progam includes
%include 'src/legacy/utils/print.asm'
%include 'src/legacy/utils/print_ext.asm'

; Fill the rest of the 512 bytes with zeros
times 512-($-$$) db 0 ; padding