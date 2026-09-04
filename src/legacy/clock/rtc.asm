; ============================================================
; rtc.asm
;
; Manejo del Real-Time Clock mediante BIOS INT 1Ah
; ============================================================


; ------------------------------------------------------------
; Variables RTC
; ------------------------------------------------------------

rtc_hour:
    db 0

rtc_minute:
    db 0

rtc_second:
    db 0


; Indica si la ultima lectura del RTC fue valida.
;
; El cronometro no depende del RTC, por lo que un error de
; lectura no debe detener el resto de la aplicacion.

rtc_available:
    db 0


; Ultimo segundo mostrado.
; FF garantiza que la primera lectura se muestre.

rtc_last_second:
    db 0xFF


; ------------------------------------------------------------
; rtc_read_time
;
; Obtiene la hora actual mediante BIOS.
;
; INT 1Ah
; AH = 02h
;
; Salida BIOS:
;
;   CH = horas
;   CL = minutos
;   DH = segundos
;   DL = indicador DST
;
; Los valores normalmente se entregan en BCD.
;
; Salida propia:
;
;   CF = 0 -> lectura correcta
;   CF = 1 -> error
; ------------------------------------------------------------

rtc_read_time:

    push ax

    ; No depender del estado de CF dejado por la rutina
    ; anterior si una BIOS antigua solo lo establece al fallar.

    clc

    mov ah, 0x02
    int 0x1A

    jc .error

    mov [rtc_hour], ch
    mov [rtc_minute], cl
    mov [rtc_second], dh

    mov byte [rtc_available], 1

    pop ax

    clc
    ret


.error:

    mov byte [rtc_available], 0

    pop ax

    stc
    ret


; ------------------------------------------------------------
; rtc_print_bcd
;
; Imprime un byte BCD como dos digitos.
;
; Ejemplo:
;
;   AL = 0x21
;
; Resultado:
;
;   "21"
; ------------------------------------------------------------

rtc_print_bcd:

    push ax
    push bx

    mov bl, al


    ; Digito de las decenas

    mov al, bl
    shr al, 4
    and al, 0x0F

    add al, '0'

    call video_print_char


    ; Digito de las unidades

    mov al, bl
    and al, 0x0F

    add al, '0'

    call video_print_char


    pop bx
    pop ax

    ret


; ------------------------------------------------------------
; rtc_print_time
;
; Imprime:
;
; HH:MM:SS
; ------------------------------------------------------------

rtc_print_time:

    push ax


    ; HH

    mov al, [rtc_hour]
    call rtc_print_bcd


    ; :

    mov al, ':'
    call video_print_char


    ; MM

    mov al, [rtc_minute]
    call rtc_print_bcd


    ; :

    mov al, ':'
    call video_print_char


    ; SS

    mov al, [rtc_second]
    call rtc_print_bcd


    pop ax

    ret
