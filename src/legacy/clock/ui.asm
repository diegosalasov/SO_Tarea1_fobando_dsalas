; ============================================================
; ui.asm
; Textos e interfaz de usuario
; ============================================================


msg_welcome:

    db 13, 10
    db "============================================================", 13, 10
    db "           RELOJ / CRONOMETRO CON ALARMA", 13, 10
    db "============================================================", 13, 10
    db 13, 10
    db "Principios de Sistemas Operativos", 13, 10
    db 13, 10
    db "Presione ENTER para iniciar.", 13, 10
    db "Presione Q para finalizar.", 13, 10
    db 13, 10
    db 0


msg_application:

    db 13, 10
    db "============================================================", 13, 10
    db "           RELOJ / CRONOMETRO CON ALARMA", 13, 10
    db "============================================================", 13, 10
    db 13, 10
    db "Aplicacion iniciada correctamente.", 13, 10
    db 13, 10
    db "Modo reloj: proximamente.", 13, 10
    db 13, 10
    db "Presione Q para finalizar.", 13, 10
    db 0


msg_goodbye:

    db 13, 10
    db 13, 10
    db "Programa finalizado.", 13, 10
    db 0


msg_clock:

    db 13, 10
    db "============================================================", 13, 10
    db "           RELOJ / CRONOMETRO CON ALARMA", 13, 10
    db "============================================================", 13, 10
    db 13, 10
    db "                         MODO RELOJ", 13, 10
    db 13, 10
    db "                        Tiempo actual", 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db "------------------------------------------------------------", 13, 10
    db "[M] Cambiar modo", 13, 10
    db "[A] Configurar alarma", 13, 10
    db "[C] Cancelar alarma", 13, 10
    db "[Q] Finalizar", 13, 10
    db "------------------------------------------------------------", 13, 10
    db 0

msg_stopwatch:

    db 13, 10
    db "============================================================", 13, 10
    db "           RELOJ / CRONOMETRO CON ALARMA", 13, 10
    db "============================================================", 13, 10
    db 13, 10
    db "                      MODO CRONOMETRO", 13, 10
    db 13, 10
    db "                     Tiempo transcurrido", 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db "------------------------------------------------------------", 13, 10
    db "[ESPACIO] Iniciar / Pausar / Reanudar", 13, 10
    db "[R] Reiniciar cronometro", 13, 10
    db "[M] Cambiar modo", 13, 10
    db "[A] Configurar alarma", 13, 10
    db "[C] Cancelar alarma", 13, 10
    db "[Q] Finalizar", 13, 10
    db "------------------------------------------------------------", 13, 10
    db 0

msg_stopwatch_paused:
    db "Estado: PAUSADO   ", 0


msg_stopwatch_running:
    db "Estado: EN MARCHA ", 0

; ============================================================
; Alarma
; ============================================================

msg_alarm_config:

    db 13, 10
    db "============================================================", 13, 10
    db "                 CONFIGURAR ALARMA", 13, 10
    db "============================================================", 13, 10
    db 13, 10
    db "                  Formato: HH:MM", 13, 10
    db 13, 10
    db "             Ingrese cuatro digitos.", 13, 10
    db "                 Ejemplo: 0730", 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db 13, 10
    db "             ESC para cancelar.", 13, 10
    db 0


msg_alarm_input:
    db "__:__", 0


msg_alarm_invalid:
    db "Hora invalida. Use HH entre 00-23 y MM entre 00-59.", 0


msg_alarm_prefix:
    db "Alarma: ", 0


msg_alarm_active:
    db " [ACTIVA]     ", 0


msg_alarm_ringing:
    db " [SONANDO]    ", 0


msg_alarm_inactive:
    db "Alarma: --:-- [INACTIVA]    ", 0


msg_alarm_alert:
    db "!!! ALARMA !!!", 0


msg_alarm_alert_blank:
    db "              ", 0


msg_rtc_unavailable:

    db "--:--:--", 0
