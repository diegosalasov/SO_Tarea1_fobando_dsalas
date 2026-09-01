; ============================================================
; app.asm
;
; Reloj / Cronometro con Alarma
; Version UEFI x86-64
; ============================================================

BITS 64
DEFAULT REL


; ============================================================
; Includes
; ============================================================

%include "constants.inc"
%include "uefi.inc"


; ============================================================
; Datos globales UEFI
; ============================================================

section .data


; Handle de esta imagen UEFI.
image_handle:
    dq 0


; EFI_SYSTEM_TABLE recibida desde el firmware.
system_table:
    dq 0


; Protocolos y tablas UEFI principales.
con_in:
    dq 0

con_out:
    dq 0

runtime_services:
    dq 0

boot_services:
    dq 0


; ============================================================
; Estado general de la aplicacion
; ============================================================

current_mode:
    db MODE_CLOCK


; ============================================================
; Codigo
; ============================================================

section .text

global efi_main


; ============================================================
; EFI Entry Point
;
; UEFI x86-64:
;
; RCX = EFI_HANDLE ImageHandle
; RDX = EFI_SYSTEM_TABLE *SystemTable
;
; ============================================================

efi_main:

    ; RSI es no volatil en la ABI x64.
    ; video_print lo modifica, por lo que conservamos
    ; el valor recibido desde el firmware.
    push rsi


    ; --------------------------------------------------------
    ; Guardar parametros entregados por UEFI
    ; --------------------------------------------------------

    mov [rel image_handle], rcx
    mov [rel system_table], rdx


    ; --------------------------------------------------------
    ; Obtener interfaces principales desde EFI_SYSTEM_TABLE
    ; --------------------------------------------------------

    mov rax, [rdx + EFI_ST_CON_IN]
    mov [rel con_in], rax


    mov rax, [rdx + EFI_ST_CON_OUT]
    mov [rel con_out], rax


    mov rax, [rdx + EFI_ST_RUNTIME_SERVICES]
    mov [rel runtime_services], rax


    mov rax, [rdx + EFI_ST_BOOT_SERVICES]
    mov [rel boot_services], rax


    ; --------------------------------------------------------
    ; Inicializar cronometro.
    ;
    ; Esto crea el EFI_EVENT utilizado posteriormente
    ; por SetTimer / CheckEvent.
    ;
    ; Un fallo del timer no impide utilizar el reloj.
    ; --------------------------------------------------------

    call stopwatch_init


    ; --------------------------------------------------------
    ; Estado inicial
    ; --------------------------------------------------------

    mov byte [rel current_mode], MODE_CLOCK


    ; --------------------------------------------------------
    ; Pantalla inicial
    ; --------------------------------------------------------

    call video_clear


    lea rsi, [rel msg_welcome]
    call video_print


; ============================================================
; Esperar confirmacion inicial
; ============================================================

wait_confirmation:

    call keyboard_read


    ; ENTER -> entrar a la aplicacion.

    cmp al, KEY_ENTER
    je application_start


    ; Q -> finalizar.

    cmp al, KEY_Q_LOWER
    je app_exit

    cmp al, KEY_Q_UPPER
    je app_exit


    ; Cualquier otra tecla se ignora.

    jmp wait_confirmation


; ============================================================
; Inicio de la aplicacion
; ============================================================

application_start:

    mov byte [rel current_mode], MODE_CLOCK


    call redraw_current_mode


    jmp main_loop


; ============================================================
; Main loop
;
; Los tres subsistemas se mantienen independientes:
;
;   1. Cronometro
;   2. RTC
;   3. Alarma
;
; El modo actual solamente determina que informacion
; se dibuja en pantalla.
; ============================================================

main_loop:


    ; --------------------------------------------------------
    ; 1. Actualizar siempre el cronometro.
    ;
    ; Puede continuar contando aunque el usuario este
    ; observando el reloj.
    ; --------------------------------------------------------

    call stopwatch_update


    ; --------------------------------------------------------
    ; 2. Leer hora actual mediante UEFI GetTime().
    ; --------------------------------------------------------

    call rtc_read_time


    ; Si falla GetTime(), no verificamos la alarma,
    ; pero la aplicacion y el cronometro siguen funcionando.

    jc .skip_alarm_check


    ; --------------------------------------------------------
    ; 3. Comprobar alarma.
    ; --------------------------------------------------------

    call alarm_check


.skip_alarm_check:


    ; --------------------------------------------------------
    ; 4. Elegir que interfaz actualizar.
    ; --------------------------------------------------------

    cmp byte [rel current_mode], MODE_CLOCK
    je .update_clock


    jmp .update_stopwatch


; ============================================================
; Actualizar pantalla del reloj
; ============================================================

.update_clock:


    ; --------------------------------------------------------
    ; ¿Tenemos una lectura valida del RTC?
    ; --------------------------------------------------------

    cmp byte [rel rtc_available], 1
    jne .show_rtc_unavailable


    ; --------------------------------------------------------
    ; Solo redibujamos HH:MM:SS cuando cambia el segundo.
    ; --------------------------------------------------------

    mov al, [rel rtc_second]


    cmp al, [rel rtc_last_second]
    je .update_alarm


    mov [rel rtc_last_second], al


    ; --------------------------------------------------------
    ; Mostrar HH:MM:SS.
    ; --------------------------------------------------------

    mov dh, CLOCK_ROW
    mov dl, CLOCK_COLUMN


    call video_set_cursor

    call rtc_print_time


    jmp .update_alarm


; ============================================================
; RTC no disponible
; ============================================================

.show_rtc_unavailable:


    ; 0xFE funciona como marca de que el mensaje ya
    ; fue mostrado.
    ;
    ; Un segundo normal nunca tendra este valor.

    cmp byte [rel rtc_last_second], 0xFE
    je .update_alarm


    mov byte [rel rtc_last_second], 0xFE


    mov dh, CLOCK_ROW
    mov dl, CLOCK_COLUMN


    call video_set_cursor


    lea rsi, [rel msg_rtc_unavailable]
    call video_print


    jmp .update_alarm


; ============================================================
; Actualizar pantalla del cronometro
; ============================================================

.update_stopwatch:


    ; Si nada cambio, no necesitamos redibujarlo.

    cmp byte [rel stopwatch_dirty], 0
    je .update_alarm


    ; --------------------------------------------------------
    ; Mostrar HH:MM:SS
    ; --------------------------------------------------------

    mov dh, STOPWATCH_ROW
    mov dl, STOPWATCH_COLUMN


    call video_set_cursor

    call stopwatch_print_time


    ; --------------------------------------------------------
    ; Mostrar estado del cronometro
    ; --------------------------------------------------------

    mov dh, STOPWATCH_STATUS_ROW
    mov dl, STOPWATCH_STATUS_COLUMN


    call video_set_cursor


    cmp byte [rel stopwatch_running], 1
    je .show_running


; ------------------------------------------------------------
; PAUSADO
; ------------------------------------------------------------

    lea rsi, [rel msg_stopwatch_paused]
    call video_print


    jmp .stopwatch_display_done


; ------------------------------------------------------------
; EN MARCHA
; ------------------------------------------------------------

.show_running:

    lea rsi, [rel msg_stopwatch_running]
    call video_print


.stopwatch_display_done:

    mov byte [rel stopwatch_dirty], 0


; ============================================================
; Actualizar alarma
; ============================================================

.update_alarm:


    ; alarm_render se encarga tanto del texto
    ;
    ; Alarma: 10:30 [ACTIVA]
    ;
    ; como del parpadeo cuando esta sonando.

    call alarm_render


; ============================================================
; Revisar teclado
; ============================================================

.check_keyboard:


    ; keyboard_check NO bloquea.

    call keyboard_check


    ; ZF = 1 -> no existe tecla.

    jz main_loop


    ; Existe una tecla pendiente.

    call keyboard_read


    ; --------------------------------------------------------
    ; Q -> finalizar
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
    ; R -> reiniciar cronometro.
    ;
    ; Puede utilizarse desde cualquiera de los modos.
    ; --------------------------------------------------------

    cmp al, KEY_R_LOWER
    je reset_stopwatch

    cmp al, KEY_R_UPPER
    je reset_stopwatch


    ; --------------------------------------------------------
    ; ESPACIO
    ;
    ; Inicia / pausa / reanuda el cronometro.
    ;
    ; Solo lo permitimos cuando el usuario esta viendo
    ; el Modo Cronometro.
    ; --------------------------------------------------------

    cmp al, KEY_SPACE
    jne main_loop


    cmp byte [rel current_mode], MODE_STOPWATCH
    jne main_loop


    call stopwatch_toggle


    jmp main_loop


; ============================================================
; switch_mode
;
; RELOJ <-> CRONOMETRO
; ============================================================

switch_mode:


    cmp byte [rel current_mode], MODE_CLOCK
    je .to_stopwatch


; ------------------------------------------------------------
; Cronometro -> Reloj
; ------------------------------------------------------------

.to_clock:

    mov byte [rel current_mode], MODE_CLOCK


    call redraw_current_mode


    jmp main_loop


; ------------------------------------------------------------
; Reloj -> Cronometro
; ------------------------------------------------------------

.to_stopwatch:

    mov byte [rel current_mode], MODE_STOPWATCH


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


    ; alarm_configure puede retornar:
    ;
    ; CF = 0 -> configurada
    ; CF = 1 -> ESC / cancelada
    ;
    ; En ambos casos debemos reconstruir la pantalla
    ; porque alarm_configure utiliza una interfaz propia.

    call alarm_configure


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
; Reconstruye la pantalla dependiendo del modo actual.
; ============================================================

redraw_current_mode:


    call video_clear


    cmp byte [rel current_mode], MODE_CLOCK
    je .clock


; ------------------------------------------------------------
; Dibujar Modo Cronometro
; ------------------------------------------------------------

.stopwatch:


    lea rsi, [rel msg_stopwatch]
    call video_print


    ; Forzar actualizacion inmediata.

    mov byte [rel stopwatch_dirty], 1
    mov byte [rel alarm_dirty], 1


    ret


; ------------------------------------------------------------
; Dibujar Modo Reloj
; ------------------------------------------------------------

.clock:


    lea rsi, [rel msg_clock]
    call video_print


    ; Fuerza que HH:MM:SS sea actualizado aunque el segundo
    ; actual coincida con el ultimo mostrado.

    mov byte [rel rtc_last_second], 0xFF


    ; La informacion de alarma tambien debe volver
    ; a dibujarse.

    mov byte [rel alarm_dirty], 1


    ret


; ============================================================
; Finalizacion
; ============================================================

app_exit:


    ; --------------------------------------------------------
    ; Detener y liberar el evento utilizado por
    ; el cronometro antes de regresar al firmware.
    ; --------------------------------------------------------

    call stopwatch_shutdown


    ; --------------------------------------------------------
    ; Mostrar despedida.
    ; --------------------------------------------------------

    lea rsi, [rel msg_goodbye]
    call video_print


    ; --------------------------------------------------------
    ; Restaurar registro no volatil guardado al entrar
    ; a efi_main.
    ; --------------------------------------------------------

    pop rsi


    ; --------------------------------------------------------
    ; EFI_SUCCESS
    ; --------------------------------------------------------

    xor eax, eax


    ; A diferencia de Legacy, una aplicacion UEFI puede
    ; retornar al firmware.

    ret


; ============================================================
; Modulos
; ============================================================

%include "video.asm"
%include "keyboard.asm"
%include "rtc.asm"
%include "stopwatch.asm"
%include "alarm.asm"
%include "ui.asm"