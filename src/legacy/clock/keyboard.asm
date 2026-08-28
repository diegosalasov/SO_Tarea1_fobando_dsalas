; ============================================================
; keyboard.asm
; Entrada de teclado mediante BIOS INT 16h
; ============================================================


; ------------------------------------------------------------
; keyboard_read
;
; Espera hasta que exista una tecla.
;
; Salida:
;   AL = codigo ASCII
;   AH = scan code
; ------------------------------------------------------------

keyboard_read:

    xor ah, ah
    int 0x16

    ret


; ------------------------------------------------------------
; keyboard_check
;
; Comprueba si existe una tecla disponible SIN bloquear.
;
; Salida:
;
;   ZF = 1 -> no hay tecla
;   ZF = 0 -> existe una tecla
;
; La tecla permanece en el buffer hasta llamar keyboard_read.
; ------------------------------------------------------------

keyboard_check:

    mov ah, 0x01
    int 0x16

    ret
