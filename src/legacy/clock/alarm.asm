; ============================================================
; alarm.asm
;
; Configuracion, comparacion y visualizacion de la alarma.
;
; La hora de la alarma se almacena en BCD para poder
; compararla directamente contra los valores obtenidos
; mediante INT 1Ah / AH=02h.
; ============================================================


; ============================================================
; Estado
; ============================================================

alarm_enabled:
    db 0

alarm_ringing:
    db 0

alarm_hour:
    db 0

alarm_minute:
    db 0

alarm_dirty:
    db 1

alarm_last_blink_second:
    db 0xFF


; Cuatro digitos:
;
; HHMM

alarm_input:
    times 4 db 0


; ============================================================
; alarm_check
;
; Compara continuamente la hora del RTC contra la alarma.
; ============================================================

alarm_check:

    push ax


    ; Si no existe alarma configurada, terminar.

    cmp byte [alarm_enabled], 1
    jne .done


    ; Si ya esta sonando no necesitamos volver a dispararla.

    cmp byte [alarm_ringing], 1
    je .done


    ; Comparar hora.

    mov al, [rtc_hour]
    cmp al, [alarm_hour]
    jne .done


    ; Comparar minutos.

    mov al, [rtc_minute]
    cmp al, [alarm_minute]
    jne .done


    ; Coincidencia encontrada.

    mov byte [alarm_ringing], 1
    mov byte [alarm_dirty], 1

    mov byte [alarm_last_blink_second], 0xFF


.done:

    pop ax
    ret


; ============================================================
; alarm_cancel
;
; Desactiva completamente la alarma.
; ============================================================

alarm_cancel:

    mov byte [alarm_enabled], 0
    mov byte [alarm_ringing], 0

    mov byte [alarm_dirty], 1

    call alarm_clear_alert

    ret


; ============================================================
; alarm_clear_alert
;
; Borra el mensaje visual de alarma.
; ============================================================

alarm_clear_alert:

    push dx
    push si

    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN

    call video_set_cursor

    mov si, msg_alarm_alert_blank
    call video_print

    mov byte [alarm_last_blink_second], 0xFF

    pop si
    pop dx

    ret


; ============================================================
; alarm_configure
;
; Permite ingresar una nueva alarma en formato:
;
; HH:MM
;
; Se escriben solamente cuatro digitos.
;
; Ejemplo:
;
; 0730
;
; En pantalla:
;
; 07:30
;
; ESC cancela la configuracion.
;
; Salida:
;
; CF = 0 -> alarma configurada
; CF = 1 -> operacion cancelada
; ============================================================

alarm_configure:

    push ax
    push bx
    push dx
    push si


.restart:

    call video_clear

    mov si, msg_alarm_config
    call video_print


    ; Mostrar plantilla inicial.

    mov dh, ALARM_INPUT_ROW
    mov dl, ALARM_INPUT_COLUMN

    call video_set_cursor

    mov si, msg_alarm_input
    call video_print


    ; BX sera nuestro indice:
    ;
    ; 0 1 2 3
    ;
    ; H H M M

    xor bx, bx


.read_key:

    call keyboard_read


    ; --------------------------------------------------------
    ; ESC -> cancelar
    ; --------------------------------------------------------

    cmp al, KEY_ESCAPE
    je .cancel


    ; --------------------------------------------------------
    ; BACKSPACE
    ; --------------------------------------------------------

    cmp al, KEY_BACKSPACE
    je .backspace


    ; --------------------------------------------------------
    ; Aceptar solamente 0-9
    ; --------------------------------------------------------

    cmp al, '0'
    jb .read_key

    cmp al, '9'
    ja .read_key


    cmp bx, 4
    jae .read_key


    ; Convertir ASCII a numero.

    sub al, '0'

    mov [alarm_input + bx], al


    ; --------------------------------------------------------
    ; Calcular posicion en pantalla.
    ;
    ; HH:MM
    ; 01 23
    ;
    ; Despues del segundo digito debemos saltar ':'.
    ; --------------------------------------------------------

    mov dh, ALARM_INPUT_ROW
    mov dl, ALARM_INPUT_COLUMN

    add dl, bl

    cmp bl, 2
    jb .position_ready

    inc dl


.position_ready:

    call video_set_cursor


    ; Recuperar digito y mostrarlo.

    mov al, [alarm_input + bx]

    add al, '0'

    call video_print_char


    inc bx


    ; Ya tenemos cuatro digitos.

    cmp bx, 4
    je .validate


    jmp .read_key


; ============================================================
; Backspace
; ============================================================

.backspace:

    cmp bx, 0
    je .read_key

    dec bx


    mov dh, ALARM_INPUT_ROW
    mov dl, ALARM_INPUT_COLUMN

    add dl, bl

    cmp bl, 2
    jb .backspace_position_ready

    inc dl


.backspace_position_ready:

    call video_set_cursor

    mov al, '_'
    call video_print_char

    jmp .read_key


; ============================================================
; Validacion
; ============================================================

.validate:

    ; --------------------------------------------------------
    ; Horas:
    ;
    ; 00 - 23
    ; --------------------------------------------------------

    mov al, [alarm_input]

    cmp al, 2
    ja .invalid


    cmp al, 2
    jne .hour_valid


    mov al, [alarm_input + 1]

    cmp al, 3
    ja .invalid


.hour_valid:


    ; --------------------------------------------------------
    ; Minutos:
    ;
    ; 00 - 59
    ; --------------------------------------------------------

    mov al, [alarm_input + 2]

    cmp al, 5
    ja .invalid


    ; --------------------------------------------------------
    ; Construir HH en BCD.
    ;
    ; Ejemplo:
    ;
    ; 1 y 8
    ;
    ; 0001 1000
    ;     0x18
    ; --------------------------------------------------------

    mov al, [alarm_input]

    shl al, 4

    or al, [alarm_input + 1]

    mov [alarm_hour], al


    ; --------------------------------------------------------
    ; Construir MM en BCD.
    ; --------------------------------------------------------

    mov al, [alarm_input + 2]

    shl al, 4

    or al, [alarm_input + 3]

    mov [alarm_minute], al


    ; Habilitar alarma.

    mov byte [alarm_enabled], 1
    mov byte [alarm_ringing], 0

    mov byte [alarm_dirty], 1

    call alarm_clear_alert


    clc
    jmp .done


; ============================================================
; Entrada incorrecta
; ============================================================

.invalid:

    mov dh, 13
    mov dl, 12

    call video_set_cursor

    mov si, msg_alarm_invalid
    call video_print


    ; Esperar una tecla antes de volver a intentar.

    call keyboard_read

    jmp .restart


; ============================================================
; Cancelar configuracion
; ============================================================

.cancel:

    stc


.done:

    pop si
    pop dx
    pop bx
    pop ax

    ret


; ============================================================
; alarm_render_info
;
; Muestra el estado de la alarma.
; ============================================================

alarm_render_info:

    cmp byte [alarm_dirty], 1
    jne .done


    push ax
    push dx
    push si


    mov dh, ALARM_INFO_ROW
    mov dl, ALARM_INFO_COLUMN

    call video_set_cursor


    ; --------------------------------------------------------
    ; Sin alarma
    ; --------------------------------------------------------

    cmp byte [alarm_enabled], 1
    je .enabled


    mov si, msg_alarm_inactive
    call video_print

    jmp .render_done


; ------------------------------------------------------------
; Alarma activa
; ------------------------------------------------------------

.enabled:

    mov si, msg_alarm_prefix
    call video_print


    mov al, [alarm_hour]
    call rtc_print_bcd


    mov al, ':'
    call video_print_char


    mov al, [alarm_minute]
    call rtc_print_bcd


    cmp byte [alarm_ringing], 1
    je .ringing


    mov si, msg_alarm_active
    call video_print

    jmp .render_done


.ringing:

    mov si, msg_alarm_ringing
    call video_print


.render_done:

    mov byte [alarm_dirty], 0


    pop si
    pop dx
    pop ax


.done:

    ret


; ============================================================
; alarm_render_visual
;
; Genera el efecto de parpadeo.
;
; Utilizamos el segundo actual del RTC para alternar entre:
;
; !!! ALARMA !!!
;
; y
;
; espacios
; ============================================================

alarm_render_visual:

    push ax
    push dx
    push si


    cmp byte [alarm_ringing], 1
    jne .done


    mov al, [rtc_second]

    cmp al, [alarm_last_blink_second]
    je .done


    mov [alarm_last_blink_second], al


    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN

    call video_set_cursor


    ; El bit menos significativo permite alternar
    ; aproximadamente una vez por segundo.

    test al, 1

    jnz .hide


.show:

    mov si, msg_alarm_alert
    call video_print

    jmp .done


.hide:

    mov si, msg_alarm_alert_blank
    call video_print


.done:

    pop si
    pop dx
    pop ax

    ret


; ============================================================
; alarm_render
; ============================================================

alarm_render:

    call alarm_render_info
    call alarm_render_visual

    ret
