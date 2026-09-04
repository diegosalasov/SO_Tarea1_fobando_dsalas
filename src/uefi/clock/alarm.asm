; ============================================================
; alarm.asm
;
; Alarma UEFI.
;
; A diferencia de Legacy, Hour y Minute de EFI_TIME
; ya estan almacenados en binario.
; ============================================================


section .data


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


; HHMM
alarm_input:
    times 4 db 0


section .text


; ============================================================
; alarm_check
; ============================================================

alarm_check:

    push rax


    cmp byte [rel alarm_enabled], 1
    jne .done


    cmp byte [rel alarm_ringing], 1
    je .done


    ; Hora

    mov al, [rel rtc_hour]

    cmp al, [rel alarm_hour]
    jne .done


    ; Minuto

    mov al, [rel rtc_minute]

    cmp al, [rel alarm_minute]
    jne .done


    ; Coincidencia.

    mov byte [rel alarm_ringing], 1

    mov byte [rel alarm_dirty], 1

    mov byte [rel alarm_last_blink_second], 0xFF


.done:

    pop rax

    ret


; ============================================================
; alarm_cancel
; ============================================================

alarm_cancel:

    mov byte [rel alarm_enabled], 0
    mov byte [rel alarm_ringing], 0

    mov byte [rel alarm_dirty], 1

    call alarm_clear_alert

    ret


; ============================================================
; alarm_clear_alert
; ============================================================

alarm_clear_alert:

    push rdx
    push rsi


    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN

    call video_set_cursor


    lea rsi, [rel msg_alarm_alert_blank]

    call video_print


    mov byte [rel alarm_last_blink_second], 0xFF


    pop rsi
    pop rdx

    ret


; ============================================================
; alarm_configure
;
; Formato:
;
; HH:MM
;
; Entrada real:
;
; cuatro digitos HHMM
;
; ESC cancela.
; ============================================================

alarm_configure:

    push rax
    push rbx
    push rdx
    push rsi


.restart:

    call video_clear


    lea rsi, [rel msg_alarm_config]

    call video_print


    mov dh, ALARM_INPUT_ROW
    mov dl, ALARM_INPUT_COLUMN

    call video_set_cursor


    lea rsi, [rel msg_alarm_input]

    call video_print


    xor ebx, ebx


.read_key:

    ; --------------------------------------------------------
    ; En lugar de bloquear completamente, mientras esperamos
    ; teclado seguimos actualizando el cronometro.
    ; --------------------------------------------------------

.wait_key:

    call keyboard_check

    jnz .key_available


    call stopwatch_update

    jmp .wait_key


.key_available:

    call keyboard_read


    ; ESC

    cmp al, KEY_ESCAPE
    je .cancel


    ; BACKSPACE

    cmp al, KEY_BACKSPACE
    je .backspace


    ; Solamente 0..9

    cmp al, '0'
    jb .read_key

    cmp al, '9'
    ja .read_key


    cmp ebx, 4
    jae .read_key


    sub al, '0'


    lea rdx, [rel alarm_input]

    mov [rdx + rbx], al


    ; --------------------------------------------------------
    ; Posicion visual
    ; --------------------------------------------------------

    mov dh, ALARM_INPUT_ROW
    mov dl, ALARM_INPUT_COLUMN

    add dl, bl


    cmp bl, 2
    jb .position_ready

    inc dl


.position_ready:

    call video_set_cursor


    lea rdx, [rel alarm_input]

    mov al, [rdx + rbx]

    add al, '0'

    call video_print_char


    inc ebx


    cmp ebx, 4
    je .validate


    jmp .read_key


; ============================================================
; Backspace
; ============================================================

.backspace:

    cmp ebx, 0
    je .read_key


    dec ebx


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

    lea rdx, [rel alarm_input]


    ; Horas 00..23

    mov al, [rdx]

    cmp al, 2
    ja .invalid


    cmp al, 2
    jne .hour_valid


    mov al, [rdx + 1]

    cmp al, 3
    ja .invalid


.hour_valid:


    ; Minutos 00..59

    mov al, [rdx + 2]

    cmp al, 5
    ja .invalid


    ; --------------------------------------------------------
    ; Convertir HH a BINARIO.
    ;
    ; Ejemplo:
    ;
    ; 1,8
    ;
    ; 1*10 + 8 = 18
    ;
    ; No utilizamos BCD.
    ; --------------------------------------------------------

    movzx eax, byte [rdx]

    imul eax, eax, 10

    movzx ecx, byte [rdx + 1]

    add eax, ecx

    mov [rel alarm_hour], al


    ; MM

    movzx eax, byte [rdx + 2]

    imul eax, eax, 10

    movzx ecx, byte [rdx + 3]

    add eax, ecx

    mov [rel alarm_minute], al


    mov byte [rel alarm_enabled], 1
    mov byte [rel alarm_ringing], 0
    mov byte [rel alarm_dirty], 1


    call alarm_clear_alert


    clc

    jmp .done


; ============================================================
; Hora invalida
; ============================================================

.invalid:

    mov dh, 13
    mov dl, 6

    call video_set_cursor


    lea rsi, [rel msg_alarm_invalid]

    call video_print


.wait_invalid_key:

    call keyboard_check

    jnz .invalid_key_available

    call stopwatch_update

    jmp .wait_invalid_key


.invalid_key_available:

    call keyboard_read

    jmp .restart


; ============================================================
; Cancelar
; ============================================================

.cancel:

    stc


.done:

    pop rsi
    pop rdx
    pop rbx
    pop rax

    ret


; ============================================================
; alarm_render_info
; ============================================================

alarm_render_info:

    cmp byte [rel alarm_dirty], 1
    jne .done


    push rax
    push rdx
    push rsi


    mov dh, ALARM_INFO_ROW
    mov dl, ALARM_INFO_COLUMN

    call video_set_cursor


    cmp byte [rel alarm_enabled], 1
    je .enabled


; ------------------------------------------------------------
; Inactiva
; ------------------------------------------------------------

    lea rsi, [rel msg_alarm_inactive]

    call video_print

    jmp .render_done


; ------------------------------------------------------------
; Activa
; ------------------------------------------------------------

.enabled:

    lea rsi, [rel msg_alarm_prefix]

    call video_print


    mov al, [rel alarm_hour]

    call rtc_print_2digits


    mov al, ':'

    call video_print_char


    mov al, [rel alarm_minute]

    call rtc_print_2digits


    cmp byte [rel alarm_ringing], 1
    je .ringing


    lea rsi, [rel msg_alarm_active]

    call video_print

    jmp .render_done


.ringing:

    lea rsi, [rel msg_alarm_ringing]

    call video_print


.render_done:

    mov byte [rel alarm_dirty], 0


    pop rsi
    pop rdx
    pop rax


.done:

    ret


; ============================================================
; alarm_render_visual
;
; Parpadeo en funcion del segundo RTC.
; ============================================================

alarm_render_visual:

    push rax
    push rdx
    push rsi


    cmp byte [rel alarm_ringing], 1
    jne .done


    cmp byte [rel rtc_available], 1
    jne .done


    mov al, [rel rtc_second]


    cmp al, [rel alarm_last_blink_second]
    je .done


    mov [rel alarm_last_blink_second], al


    mov dh, ALARM_ALERT_ROW
    mov dl, ALARM_ALERT_COLUMN

    call video_set_cursor


    test al, 1

    jnz .hide


.show:

    lea rsi, [rel msg_alarm_alert]

    call video_print

    jmp .done


.hide:

    lea rsi, [rel msg_alarm_alert_blank]

    call video_print


.done:

    pop rsi
    pop rdx
    pop rax

    ret


; ============================================================
; alarm_render
; ============================================================

alarm_render:

    call alarm_render_info
    call alarm_render_visual

    ret