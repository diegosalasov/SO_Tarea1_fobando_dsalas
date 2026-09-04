; ============================================================
; stopwatch.asm
;
; Cronometro independiente del RTC utilizando
; EFI_BOOT_SERVICES Timer Events.
; ============================================================


section .data


; ============================================================
; Estado
; ============================================================

stopwatch_running:
    db 0

stopwatch_hours:
    db 0

stopwatch_minutes:
    db 0

stopwatch_seconds:
    db 0

stopwatch_dirty:
    db 1


; Evento UEFI asociado al timer.

stopwatch_event:
    dq 0


; Indica que CreateEvent se ejecuto correctamente.

stopwatch_initialized:
    db 0


section .text


; ============================================================
; stopwatch_init
;
; Crea el evento que posteriormente utilizaremos como
; temporizador periodico.
;
; Debe llamarse una unica vez al iniciar la aplicacion.
;
; CF = 0 -> correcto
; CF = 1 -> error
; ============================================================

stopwatch_init:

    push rax
    push rcx
    push rdx
    push r8
    push r9
    push r11


    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_CREATE_EVENT]


    ; CreateEvent(
    ;     EVT_TIMER,
    ;     0,
    ;     NULL,
    ;     NULL,
    ;     &stopwatch_event
    ; )

    mov ecx, EVT_TIMER

    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d

    lea r11, [rel stopwatch_event]


    EFI_CALL5 rax, r11


    test rax, rax
    jnz .error


    mov byte [rel stopwatch_initialized], 1


    pop r11
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax

    clc

    ret


.error:

    mov byte [rel stopwatch_initialized], 0


    pop r11
    pop r9
    pop r8
    pop rdx
    pop rcx
    pop rax

    stc

    ret


; ============================================================
; stopwatch_timer_start
;
; Configura el evento como timer periodico de 1 segundo.
; ============================================================

stopwatch_timer_start:

    cmp byte [rel stopwatch_initialized], 1
    jne .done


    push rax
    push rcx
    push rdx
    push r8


    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_SET_TIMER]


    mov rcx, [rel stopwatch_event]

    mov edx, TIMER_PERIODIC

    mov r8, ONE_SECOND_100NS


    EFI_CALL rax


    pop r8
    pop rdx
    pop rcx
    pop rax


.done:

    ret


; ============================================================
; stopwatch_timer_stop
; ============================================================

stopwatch_timer_stop:

    cmp byte [rel stopwatch_initialized], 1
    jne .done


    push rax
    push rcx
    push rdx
    push r8


    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_SET_TIMER]


    mov rcx, [rel stopwatch_event]

    mov edx, TIMER_CANCEL

    xor r8d, r8d


    EFI_CALL rax


    pop r8
    pop rdx
    pop rcx
    pop rax


.done:

    ret


; ============================================================
; stopwatch_toggle
;
; PAUSADO <-> EN MARCHA
; ============================================================

stopwatch_toggle:

    cmp byte [rel stopwatch_running], 0
    je .start


; ------------------------------------------------------------
; Pausar
; ------------------------------------------------------------

.pause:

    call stopwatch_timer_stop

    mov byte [rel stopwatch_running], 0
    mov byte [rel stopwatch_dirty], 1

    ret


; ------------------------------------------------------------
; Iniciar / reanudar
; ------------------------------------------------------------

.start:

    call stopwatch_timer_start

    mov byte [rel stopwatch_running], 1
    mov byte [rel stopwatch_dirty], 1

    ret


; ============================================================
; stopwatch_reset
;
; Reinicia HH:MM:SS.
;
; Si estaba corriendo, continua corriendo.
; ============================================================

stopwatch_reset:

    mov byte [rel stopwatch_hours], 0
    mov byte [rel stopwatch_minutes], 0
    mov byte [rel stopwatch_seconds], 0

    mov byte [rel stopwatch_dirty], 1


    ; Si estaba corriendo reiniciamos tambien la fase
    ; del timer para que el siguiente segundo sea completo.

    cmp byte [rel stopwatch_running], 1
    jne .done


    call stopwatch_timer_stop
    call stopwatch_timer_start


.done:

    ret


; ============================================================
; stopwatch_update
;
; Comprueba el evento SIN bloquear.
;
; EFI_SUCCESS:
;   transcurrio un periodo.
;
; EFI_NOT_READY:
;   todavia no.
; ============================================================

stopwatch_update:

    cmp byte [rel stopwatch_running], 1
    jne .done

    cmp byte [rel stopwatch_initialized], 1
    jne .done


    push rax
    push rcx


    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_CHECK_EVENT]


    mov rcx, [rel stopwatch_event]


    EFI_CALL rax


    ; EFI_SUCCESS == 0

    test rax, rax
    jnz .no_tick


    call stopwatch_increment_second

    mov byte [rel stopwatch_dirty], 1


.no_tick:

    pop rcx
    pop rax


.done:

    ret


; ============================================================
; stopwatch_increment_second
; ============================================================

stopwatch_increment_second:

    inc byte [rel stopwatch_seconds]

    cmp byte [rel stopwatch_seconds], 60
    jb .done


    mov byte [rel stopwatch_seconds], 0

    inc byte [rel stopwatch_minutes]

    cmp byte [rel stopwatch_minutes], 60
    jb .done


    mov byte [rel stopwatch_minutes], 0

    inc byte [rel stopwatch_hours]

    cmp byte [rel stopwatch_hours], 100
    jb .done


    mov byte [rel stopwatch_hours], 0


.done:

    ret


; ============================================================
; stopwatch_print_2digits
;
; AL = valor 0..99
; ============================================================

stopwatch_print_2digits:

    push rax
    push rbx


    xor ah, ah

    mov bl, 10

    div bl


    ; AL = decenas
    ; AH = unidades

    add al, '0'

    call video_print_char


    mov al, ah

    add al, '0'

    call video_print_char


    pop rbx
    pop rax

    ret


; ============================================================
; stopwatch_print_time
;
; HH:MM:SS
; ============================================================

stopwatch_print_time:

    push rax


    mov al, [rel stopwatch_hours]
    call stopwatch_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [rel stopwatch_minutes]
    call stopwatch_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [rel stopwatch_seconds]
    call stopwatch_print_2digits


    pop rax

    ret


; ============================================================
; stopwatch_shutdown
;
; Libera el evento antes de regresar al firmware.
; ============================================================

stopwatch_shutdown:

    cmp byte [rel stopwatch_initialized], 1
    jne .done


    call stopwatch_timer_stop


    push rax
    push rcx


    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_CLOSE_EVENT]

    mov rcx, [rel stopwatch_event]

    EFI_CALL rax


    pop rcx
    pop rax


    mov byte [rel stopwatch_initialized], 0


.done:

    ret