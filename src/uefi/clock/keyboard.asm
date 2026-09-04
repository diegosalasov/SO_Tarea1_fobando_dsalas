; ============================================================
; keyboard.asm
;
; Entrada mediante EFI_SIMPLE_TEXT_INPUT_PROTOCOL
; ============================================================


section .data


; EFI_INPUT_KEY:
;
; UINT16 ScanCode
; CHAR16 UnicodeChar

input_key:
    dw 0
    dw 0


; keyboard_check consume ReadKeyStroke.
; Guardamos la tecla para que keyboard_read pueda
; devolverla despues.

key_pending:
    db 0


section .text


; ============================================================
; keyboard_check
;
; Mantiene la misma interfaz conceptual de Legacy:
;
; ZF = 1 -> no hay tecla
; ZF = 0 -> hay tecla
; ============================================================

keyboard_check:

    cmp byte [rel key_pending], 1
    je .available


    push rax
    push rcx
    push rdx


    mov rcx, [rel con_in]

    lea rdx, [rel input_key]

    mov rax, [rcx + EFI_CONIN_READ_KEY_STROKE]

    EFI_CALL rax


    test rax, rax
    jnz .not_available_restore


    mov byte [rel key_pending], 1


    pop rdx
    pop rcx
    pop rax


.available:

    ; key_pending = 1
    ; produce ZF = 0

    cmp byte [rel key_pending], 0

    ret


.not_available_restore:

    pop rdx
    pop rcx
    pop rax


    ; key_pending = 0
    ; produce ZF = 1

    cmp byte [rel key_pending], 0

    ret


; ============================================================
; keyboard_read
;
; Espera hasta tener una tecla.
;
; Salida:
;
;   AL = caracter compatible con la interfaz Legacy
;
; Para caracteres normales se utiliza UnicodeChar.
;
; Para teclas especiales de UEFI, como ESC, se traduce
; ScanCode al valor esperado por la aplicacion.
; ============================================================

keyboard_read:

.wait:

    cmp byte [rel key_pending], 1
    je .return_key


    call keyboard_check

    jz .wait


.return_key:

    ; --------------------------------------------------------
    ; Primero intentar devolver UnicodeChar.
    ;
    ; EFI_INPUT_KEY:
    ;
    ; offset 0 -> ScanCode
    ; offset 2 -> UnicodeChar
    ; --------------------------------------------------------

    movzx eax, word [rel input_key + 2]


    ; Si UnicodeChar != 0, tenemos una tecla normal:
    ;
    ; A, C, M, R, Q, ENTER, BACKSPACE, SPACE...
    ;
    ; La devolvemos directamente.

    test ax, ax
    jnz .consume


    ; --------------------------------------------------------
    ; UnicodeChar == 0
    ;
    ; Se trata de una tecla especial UEFI.
    ; Revisamos ScanCode.
    ; --------------------------------------------------------

    movzx edx, word [rel input_key]


    ; ESC

    cmp dx, UEFI_SCAN_ESC
    je .escape


    ; Tecla especial que nuestra aplicacion no utiliza.
    ;
    ; AL = 0

    xor eax, eax

    jmp .consume


; ------------------------------------------------------------
; Traducir ESC UEFI al valor utilizado por nuestra
; aplicacion y por la version Legacy.
; ------------------------------------------------------------

.escape:

    mov eax, KEY_ESCAPE


.consume:

    mov byte [rel key_pending], 0

    ret