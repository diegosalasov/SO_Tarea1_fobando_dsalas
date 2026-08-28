; ============================================================
; stopwatch.asm
;
; Cronometro independiente utilizando el contador
; de ticks de BIOS.
;
; INT 1Ah
; AH = 00h
; ============================================================


; ============================================================
; Estado del cronometro
; ============================================================

stopwatch_running:
    db 0

stopwatch_hours:
    db 0

stopwatch_minutes:
    db 0

stopwatch_seconds:
    db 0


; Ultimo valor de ticks leido.
stopwatch_last_tick:
    dw 0


; Ticks acumulados que aun no forman un segundo.
stopwatch_tick_accum:
    dw 0


; Fase para utilizar la secuencia:
;
; 18, 18, 18, 18, 19
;
stopwatch_phase:
    db 0


; Indica que la pantalla necesita actualizarse.
stopwatch_dirty:
    db 1


; ============================================================
; timer_get_ticks
;
; Obtiene el contador de ticks del BIOS.
;
; INT 1Ah
; AH = 00h
;
; Salida:
;
;   CX:DX = ticks desde medianoche
;   AL    = contador de pasos por medianoche
;
; ============================================================

timer_get_ticks:

    xor ah, ah
    int 0x1A

    ret


; ============================================================
; stopwatch_toggle
;
; Alterna:
;
; PAUSADO -> CORRIENDO
; CORRIENDO -> PAUSADO
;
; ============================================================

stopwatch_toggle:

    cmp byte [stopwatch_running], 0
    je .start


; ------------------------------------------------------------
; Pausar
; ------------------------------------------------------------

.pause:

    mov byte [stopwatch_running], 0
    mov byte [stopwatch_dirty], 1

    ret


; ------------------------------------------------------------
; Iniciar / reanudar
; ------------------------------------------------------------

.start:

    ; Leer el tick actual para que el tiempo durante
    ; la pausa NO sea agregado al cronometro.

    call timer_get_ticks

    mov [stopwatch_last_tick], dx

    mov byte [stopwatch_running], 1
    mov byte [stopwatch_dirty], 1

    ret


; ============================================================
; stopwatch_reset
;
; Reinicia el cronometro a:
;
; 00:00:00
;
; Si estaba corriendo, continua corriendo.
; ============================================================

stopwatch_reset:

    mov byte [stopwatch_hours], 0
    mov byte [stopwatch_minutes], 0
    mov byte [stopwatch_seconds], 0

    mov word [stopwatch_tick_accum], 0
    mov byte [stopwatch_phase], 0

    mov byte [stopwatch_dirty], 1


    ; Si esta detenido no necesitamos actualizar last_tick.

    cmp byte [stopwatch_running], 0
    je .done


    ; Si esta corriendo, reiniciamos la referencia temporal.

    call timer_get_ticks

    mov [stopwatch_last_tick], dx


.done:

    ret


; ============================================================
; stopwatch_update
;
; Actualiza el cronometro utilizando ticks BIOS.
;
; Esta rutina NO bloquea.
; ============================================================

stopwatch_update:

    cmp byte [stopwatch_running], 1
    jne .done


    ; Obtener ticks actuales.

    call timer_get_ticks


    ; --------------------------------------------------------
    ; Calcular cuantos ticks transcurrieron desde la ultima
    ; lectura.
    ;
    ; La resta de 16 bits funciona tambien cuando DX hace
    ; wrap-around, siempre que llamemos frecuentemente.
    ; --------------------------------------------------------

    mov ax, dx

    sub ax, [stopwatch_last_tick]

    mov [stopwatch_last_tick], dx


    ; Si no paso ningun tick, terminar.

    cmp ax, 0
    je .done


    ; Acumular ticks.

    add [stopwatch_tick_accum], ax


.process_ticks:

    ; --------------------------------------------------------
    ; Normalmente usamos 18 ticks.
    ;
    ; Cada quinto segundo utilizamos 19.
    ; --------------------------------------------------------

    mov bx, 18

    cmp byte [stopwatch_phase], 4
    jne .check_ticks

    mov bx, 19


.check_ticks:

    mov ax, [stopwatch_tick_accum]

    cmp ax, bx
    jb .done


    ; Consumir los ticks correspondientes al segundo.

    sub word [stopwatch_tick_accum], bx


    ; Avanzar fase.

    inc byte [stopwatch_phase]

    cmp byte [stopwatch_phase], 5
    jb .increment_time

    mov byte [stopwatch_phase], 0


.increment_time:

    call stopwatch_increment_second

    mov byte [stopwatch_dirty], 1


    ; Puede que hayan transcurrido varios segundos,
    ; por lo tanto revisamos nuevamente.

    jmp .process_ticks


.done:

    ret


; ============================================================
; stopwatch_increment_second
;
; Incrementa:
;
; HH:MM:SS
; ============================================================

stopwatch_increment_second:

    inc byte [stopwatch_seconds]

    cmp byte [stopwatch_seconds], 60
    jb .done


    ; 60 segundos -> 1 minuto

    mov byte [stopwatch_seconds], 0

    inc byte [stopwatch_minutes]

    cmp byte [stopwatch_minutes], 60
    jb .done


    ; 60 minutos -> 1 hora

    mov byte [stopwatch_minutes], 0

    inc byte [stopwatch_hours]

    cmp byte [stopwatch_hours], 100
    jb .done


    ; Para mantener HH en dos digitos,
    ; despues de 99:59:59 vuelve a 00:00:00.

    mov byte [stopwatch_hours], 0


.done:

    ret


; ============================================================
; stopwatch_print_2digits
;
; Convierte un numero binario entre 0 y 99 en dos
; caracteres ASCII.
;
; Entrada:
;
;   AL = numero
;
; Ejemplo:
;
;   AL = 7
;
; imprime:
;
;   07
;
; ============================================================

stopwatch_print_2digits:

    push ax
    push bx


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


    pop bx
    pop ax

    ret


; ============================================================
; stopwatch_print_time
;
; Imprime:
;
; HH:MM:SS
; ============================================================

stopwatch_print_time:

    push ax


    mov al, [stopwatch_hours]
    call stopwatch_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [stopwatch_minutes]
    call stopwatch_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [stopwatch_seconds]
    call stopwatch_print_2digits


    pop ax

    ret