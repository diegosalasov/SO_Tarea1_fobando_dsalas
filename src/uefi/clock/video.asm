; ============================================================
; video.asm
;
; Salida de video mediante
; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
; ============================================================


section .data

char16_buffer:
    dw 0
    dw 0


section .text


; ============================================================
; video_clear
; ============================================================

video_clear:

    push rax
    push rcx

    mov rcx, [rel con_out]

    mov rax, [rcx + EFI_CONOUT_CLEAR_SCREEN]

    EFI_CALL rax

    pop rcx
    pop rax

    ret


; ============================================================
; video_print_char
;
; Entrada:
;   AL = caracter ASCII
;
; OutputString necesita CHAR16, por lo que convertimos
; temporalmente el caracter.
; ============================================================

video_print_char:

    push rax
    push rcx
    push rdx


    movzx eax, al

    mov word [rel char16_buffer], ax
    mov word [rel char16_buffer + 2], 0


    mov rcx, [rel con_out]

    lea rdx, [rel char16_buffer]

    mov rax, [rcx + EFI_CONOUT_OUTPUT_STRING]

    EFI_CALL rax


    pop rdx
    pop rcx
    pop rax

    ret


; ============================================================
; video_print
;
; RSI -> cadena ASCII terminada en 0
;
; Esto permite reciclar ui.asm de Legacy.
; ============================================================

video_print:

.print_loop:

    mov al, [rsi]

    test al, al
    jz .done

    inc rsi

    call video_print_char

    jmp .print_loop


.done:

    ret


; ============================================================
; video_set_cursor
;
; Conservamos la misma interfaz que Legacy:
;
; DH = fila
; DL = columna
; ============================================================

video_set_cursor:

    push rax
    push rcx
    push rdx
    push r8


    ; No podemos hacer movzx r8d, dh directamente
    ; porque DH no puede combinarse con un prefijo REX.

    movzx eax, dh
    mov r8d, eax

    movzx edx, dl


    mov rcx, [rel con_out]

    mov rax, [rcx + EFI_CONOUT_SET_CURSOR_POSITION]

    EFI_CALL rax


    pop r8
    pop rdx
    pop rcx
    pop rax

    ret