; ============================================================
; uefi.inc
; Definiciones UEFI x86-64
; ============================================================


; ============================================================
; EFI_STATUS
; ============================================================

EFI_SUCCESS     equ 0


; ============================================================
; EFI_SYSTEM_TABLE - offsets x86-64
; ============================================================

EFI_ST_CON_IN               equ 48
EFI_ST_CON_OUT              equ 64
EFI_ST_RUNTIME_SERVICES     equ 88
EFI_ST_BOOT_SERVICES        equ 96


; ============================================================
; EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL
; ============================================================

EFI_CONOUT_OUTPUT_STRING        equ 8
EFI_CONOUT_CLEAR_SCREEN         equ 48
EFI_CONOUT_SET_CURSOR_POSITION  equ 56


; ============================================================
; EFI_SIMPLE_TEXT_INPUT_PROTOCOL
; ============================================================

EFI_CONIN_READ_KEY_STROKE       equ 8


; ============================================================
; EFI_RUNTIME_SERVICES
; ============================================================

EFI_RT_GET_TIME                 equ 24


; ============================================================
; EFI_BOOT_SERVICES
; ============================================================

EFI_BS_STALL                    equ 248


; ============================================================
; EFI_TIME
; ============================================================

EFI_TIME_YEAR       equ 0
EFI_TIME_MONTH      equ 2
EFI_TIME_DAY        equ 3
EFI_TIME_HOUR       equ 4
EFI_TIME_MINUTE     equ 5
EFI_TIME_SECOND     equ 6

EFI_TIME_SIZE       equ 16

; ============================================================
; EFI Scan Codes
; ============================================================

UEFI_SCAN_ESC       equ 0x17


; ============================================================
; EFI_BOOT_SERVICES - eventos y timers
; ============================================================

EFI_BS_CREATE_EVENT     equ 80
EFI_BS_SET_TIMER        equ 88
EFI_BS_CLOSE_EVENT      equ 112
EFI_BS_CHECK_EVENT      equ 120


; ============================================================
; Tipos de eventos
; ============================================================

EVT_TIMER               equ 0x80000000


; ============================================================
; EFI_TIMER_DELAY
; ============================================================

TIMER_CANCEL            equ 0
TIMER_PERIODIC          equ 1
TIMER_RELATIVE          equ 2


; ============================================================
; Unidad temporal UEFI
;
; TriggerTime se expresa en unidades de 100 ns.
;
; 10 000 000 * 100 ns = 1 segundo
; ============================================================

ONE_SECOND_100NS        equ 10000000

; ============================================================
; Macro para llamar funciones UEFI.
;
; UEFI x86-64 utiliza Microsoft x64 ABI:
;
; RCX = argumento 1
; RDX = argumento 2
; R8  = argumento 3
; R9  = argumento 4
;
; Se requieren 32 bytes de shadow space y alineamiento.
;
; El registro con la direccion de la funcion se pasa
; como parametro al macro.
; ============================================================

%macro EFI_CALL 1

    push rbp
    mov rbp, rsp

    and rsp, -16
    sub rsp, 32

    call %1

    mov rsp, rbp
    pop rbp

%endmacro

; ============================================================
; EFI_CALL5
;
; Llamada UEFI x86-64 con un quinto argumento.
;
; Los primeros cuatro:
;
; RCX
; RDX
; R8
; R9
;
; El quinto se coloca en la pila.
;
; Uso:
;
; EFI_CALL5 rax, r11
;
; donde r11 contiene el quinto argumento.
; ============================================================

%macro EFI_CALL5 2

    push rbp
    mov rbp, rsp

    and rsp, -16

    ; 32 bytes shadow space
    ; 8 bytes quinto argumento
    ; padding hasta mantener alineamiento

    sub rsp, 48

    mov qword [rsp + 32], %2

    call %1

    mov rsp, rbp

    pop rbp

%endmacro