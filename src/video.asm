; ============================================================
; video.asm
; Rutinas relacionadas con la salida de video mediante BIOS
; ============================================================


; ------------------------------------------------------------
; video_clear
;
; Limpia la pantalla estableciendo modo texto 80x25.
;
; INT 10h
; AH = 00h -> establecer modo de video
; AL = 03h -> modo texto 80x25, 16 colores
; ------------------------------------------------------------

video_clear:
    push ax

    mov ax, 0x0003
    int 0x10

    pop ax
    ret


; ------------------------------------------------------------
; video_print
;
; Imprime una cadena terminada en 0.
;
; Entrada:
;   DS:SI -> direccion de la cadena
;
; Utiliza:
;   INT 10h
;   AH = 0Eh -> Teletype Output
; ------------------------------------------------------------

video_print:
    push ax
    push bx

.print_loop:

    lodsb

    cmp al, 0
    je .done

    mov ah, 0x0E

    ; Pagina de video 0
    mov bh, 0x00

    ; Atributo/color
    mov bl, 0x07

    int 0x10

    jmp .print_loop

.done:
    pop bx
    pop ax

    ret

; ------------------------------------------------------------
; video_set_cursor
;
; Posiciona el cursor.
;
; Entrada:
;   DH = fila
;   DL = columna
;
; INT 10h
; AH = 02h
; BH = pagina de video
; ------------------------------------------------------------

video_set_cursor:

    push ax
    push bx

    mov ah, 0x02
    mov bh, 0x00

    int 0x10

    pop bx
    pop ax

    ret


; ------------------------------------------------------------
; video_print_char
;
; Imprime un solo caracter.
;
; Entrada:
;   AL = caracter ASCII
; ------------------------------------------------------------

video_print_char:

    push ax
    push bx

    mov ah, 0x0E
    mov bh, 0x00
    mov bl, 0x07

    int 0x10

    pop bx
    pop ax

    ret