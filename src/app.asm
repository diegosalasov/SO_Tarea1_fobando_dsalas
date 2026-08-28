; ============================================================
; app.asm
;
; Reloj / Cronometro con Alarma
;
; Aplicacion x86 de 16 bits utilizando servicios BIOS.
; ============================================================


BITS 16


; ------------------------------------------------------------
; Durante el desarrollo generamos dos versiones:
;
; DOS_TEST:
;   .COM ejecutable temporalmente mediante DOSBox.
;
; Version normal:
;   binario plano que posteriormente sera cargado
;   por nuestro boot loader.
; ------------------------------------------------------------

%ifdef DOS_TEST

    ORG 0x100

%else

    ORG 0x0000

%endif


%include "constants.inc"


; El primer codigo ejecutado siempre salta a start.
jmp start


; ============================================================
; Modulos
; ============================================================

%include "video.asm"
%include "keyboard.asm"
%include "rtc.asm"
%include "ui.asm"
%include "stopwatch.asm"
%include "alarm.asm"


; ============================================================
; Estado general de la aplicacion
; ============================================================

current_mode:
    db MODE_CLOCK


; ============================================================
; Punto de entrada
; ============================================================

start:

    ; --------------------------------------------------------
    ; Inicializacion de segmentos
    ; --------------------------------------------------------

    mov ax, cs

    mov ds, ax
    mov es, ax

    cld


%ifndef DOS_TEST

    ; En la version bare-metal tambien debemos
    ; preparar nuestra propia pila.

    cli

    mov ss, ax
    mov sp, 0xFFFE

    sti

%endif


    ; --------------------------------------------------------
    ; Pantalla inicial
    ; --------------------------------------------------------

    call video_clear

    mov si, msg_welcome
    call video_print


; ============================================================
; Esperar confirmacion inicial
; ============================================================

wait_confirmation:

    call keyboard_read

    ; ENTER -> iniciar aplicacion

    cmp al, KEY_ENTER
    je application_start


    ; Q -> finalizar

    cmp al, KEY_Q_LOWER
    je app_exit

    cmp al, KEY_Q_UPPER
    je app_exit


    ; Cualquier otra tecla se ignora

    jmp wait_confirmation


; ============================================================
; Inicio de la aplicacion interactiva
; ============================================================

application_start:

    mov byte [current_mode], MODE_CLOCK

    call redraw_current_mode

    jmp main_loop


; ============================================================
; Main loop
; ============================================================

main_loop:

    ; --------------------------------------------------------
    ; 1. Actualizar siempre el cronometro.
    ;
    ; El cronometro utiliza los ticks del BIOS y no depende
    ; de que el RTC pueda entregar la hora actual.
    ; --------------------------------------------------------

    call stopwatch_update


    ; --------------------------------------------------------
    ; 2. Intentar leer el RTC.
    ;
    ; Un error del RTC no es fatal: el cronometro y el teclado
    ; deben continuar funcionando. Solamente omitimos la
    ; comprobacion de la alarma hasta obtener una hora valida.
    ; --------------------------------------------------------

    call rtc_read_time

    jc .skip_alarm_check

    ; --------------------------------------------------------
    ; Comprobar alarma independientemente del modo visible.
    ; --------------------------------------------------------

    call alarm_check


.skip_alarm_check:

    ; --------------------------------------------------------
    ; 3. Actualizar solamente la interfaz correspondiente
    ; al modo actual.
    ; --------------------------------------------------------

    cmp byte [current_mode], MODE_CLOCK
    je .update_clock

    jmp .update_stopwatch


; ============================================================
; Actualizar pantalla del reloj
; ============================================================

.update_clock:

    cmp byte [rtc_available], 1
    jne .show_rtc_unavailable


    mov al, [rtc_second]

    cmp al, [rtc_last_second]
    je .update_alarm

    mov [rtc_last_second], al

    mov dh, CLOCK_ROW
    mov dl, CLOCK_COLUMN

    call video_set_cursor

    call rtc_print_time

    jmp .update_alarm


; ------------------------------------------------------------
; El reloj no esta disponible.
;
; FE no es un segundo BCD valido, por lo que tambien funciona
; como marca para evitar redibujar el mensaje en cada vuelta.
; ------------------------------------------------------------

.show_rtc_unavailable:

    cmp byte [rtc_last_second], 0xFE
    je .update_alarm

    mov byte [rtc_last_second], 0xFE

    mov dh, CLOCK_ROW
    mov dl, CLOCK_COLUMN

    call video_set_cursor

    mov si, msg_rtc_unavailable
    call video_print

    jmp .update_alarm


; ============================================================
; Actualizar pantalla del cronometro
; ============================================================

.update_stopwatch:

    cmp byte [stopwatch_dirty], 0
    je .update_alarm


    ; --------------------------------------------------------
    ; Mostrar HH:MM:SS
    ; --------------------------------------------------------

    mov dh, STOPWATCH_ROW
    mov dl, STOPWATCH_COLUMN

    call video_set_cursor

    call stopwatch_print_time


    ; --------------------------------------------------------
    ; Mostrar estado
    ; --------------------------------------------------------

    mov dh, STOPWATCH_STATUS_ROW
    mov dl, STOPWATCH_STATUS_COLUMN

    call video_set_cursor


    cmp byte [stopwatch_running], 1
    je .show_running


    mov si, msg_stopwatch_paused
    call video_print

    jmp .stopwatch_display_done


.show_running:

    mov si, msg_stopwatch_running
    call video_print


.stopwatch_display_done:

    mov byte [stopwatch_dirty], 0


; ============================================================
; Actualizacion visual de alarma
; ============================================================

.update_alarm:

    call alarm_render


; ============================================================
; Teclado
; ============================================================

.check_keyboard:

    call keyboard_check

    jz main_loop


    call keyboard_read


    ; --------------------------------------------------------
    ; Q -> salir
    ; --------------------------------------------------------

    cmp al, KEY_Q_LOWER
    je app_exit

    cmp al, KEY_Q_UPPER
    je app_exit


    ; --------------------------------------------------------
    ; M -> cambiar modo
    ; --------------------------------------------------------

    cmp al, KEY_M_LOWER
    je switch_mode

    cmp al, KEY_M_UPPER
    je switch_mode

    ; --------------------------------------------------------
    ; A -> configurar alarma
    ; --------------------------------------------------------

    cmp al, KEY_A_LOWER
    je configure_alarm

    cmp al, KEY_A_UPPER
    je configure_alarm


    ; --------------------------------------------------------
    ; C -> cancelar alarma
    ; --------------------------------------------------------

    cmp al, KEY_C_LOWER
    je cancel_alarm

    cmp al, KEY_C_UPPER
    je cancel_alarm

    ; --------------------------------------------------------
    ; R -> reiniciar cronometro
    ;
    ; Funciona incluso estando en Modo Reloj.
    ; --------------------------------------------------------

    cmp al, KEY_R_LOWER
    je reset_stopwatch

    cmp al, KEY_R_UPPER
    je reset_stopwatch


    ; --------------------------------------------------------
    ; ESPACIO
    ;
    ; Solo tiene efecto si estamos viendo el cronometro.
    ; --------------------------------------------------------

    cmp al, KEY_SPACE
    jne main_loop


    cmp byte [current_mode], MODE_STOPWATCH
    jne main_loop


    call stopwatch_toggle

    jmp main_loop



; ============================================================
; switch_mode
; ============================================================

switch_mode:

    cmp byte [current_mode], MODE_CLOCK
    je .to_stopwatch


; ------------------------------------------------------------
; Cronometro -> Reloj
; ------------------------------------------------------------

.to_clock:

    mov byte [current_mode], MODE_CLOCK

    call redraw_current_mode

    jmp main_loop


; ------------------------------------------------------------
; Reloj -> Cronometro
; ------------------------------------------------------------

.to_stopwatch:

    mov byte [current_mode], MODE_STOPWATCH

    call redraw_current_mode

    jmp main_loop


; ============================================================
; reset_stopwatch
; ============================================================

reset_stopwatch:

    call stopwatch_reset

    jmp main_loop

; ============================================================
; configure_alarm
; ============================================================

configure_alarm:

    call alarm_configure


    ; CF=1 significa que el usuario presiono ESC.
    ;
    ; En ambos casos debemos volver a dibujar la pantalla
    ; principal porque la pantalla de configuracion reemplazo
    ; la interfaz anterior.

    call redraw_current_mode

    jmp main_loop


; ============================================================
; cancel_alarm
; ============================================================

cancel_alarm:

    call alarm_cancel

    jmp main_loop


; ============================================================
; redraw_current_mode
;
; Reconstruye la interfaz dependiendo del modo activo.
; ============================================================

redraw_current_mode:

    call video_clear


    cmp byte [current_mode], MODE_CLOCK
    je .clock


; ------------------------------------------------------------
; Cronometro
; ------------------------------------------------------------

.stopwatch:

    mov si, msg_stopwatch
    call video_print

    mov byte [stopwatch_dirty], 1
    mov byte [alarm_dirty], 1

    ret


; ------------------------------------------------------------
; Reloj
; ------------------------------------------------------------

.clock:

    mov si, msg_clock
    call video_print

    mov byte [rtc_last_second], 0xFF
    mov byte [alarm_dirty], 1

    ret

; ============================================================
; Finalizacion
; ============================================================

app_exit:

    mov si, msg_goodbye
    call video_print


%ifdef DOS_TEST

    ; --------------------------------------------------------
    ; Solamente utilizado durante pruebas con DOSBox.
    ;
    ; INT 21h / AH=4Ch pertenece a DOS y NO sera utilizado
    ; por nuestra aplicacion bare-metal final.
    ; --------------------------------------------------------

    mov ax, 0x4C00
    int 0x21

%else

    ; --------------------------------------------------------
    ; En bare-metal no existe un sistema operativo al cual
    ; regresar.
    ; --------------------------------------------------------

    cli

.halt:

    hlt
    jmp .halt

%endif
