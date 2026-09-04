; ============================================================
; boot.asm
;
; Cargador UEFI x86-64.
;
; El firmware carga este archivo como EFI/BOOT/BOOTX64.EFI.
; El cargador abre EFI/CLOCK/CLOCK.EFI desde el mismo volumen,
; lo carga mediante LoadImage() y le transfiere el control con
; StartImage().
; ============================================================

BITS 64
DEFAULT REL

global efi_main


; ============================================================
; Constantes UEFI x86-64
; ============================================================

EFI_SUCCESS                 equ 0
EFI_LOAD_ERROR              equ 0x8000000000000001
EFI_NOT_FOUND               equ 0x800000000000000E

EFI_LOADER_DATA             equ 2
EFI_FILE_MODE_READ          equ 1

APP_BUFFER_SIZE             equ 1024 * 1024

EFI_ST_CON_OUT              equ 64
EFI_ST_BOOT_SERVICES        equ 96

EFI_CONOUT_OUTPUT_STRING    equ 8

EFI_BS_ALLOCATE_POOL        equ 64
EFI_BS_FREE_POOL            equ 72
EFI_BS_HANDLE_PROTOCOL      equ 152
EFI_BS_LOAD_IMAGE           equ 200
EFI_BS_START_IMAGE          equ 208
EFI_BS_UNLOAD_IMAGE         equ 224
EFI_BS_STALL                equ 248
EFI_BS_SET_WATCHDOG_TIMER   equ 256

EFI_LOADED_IMAGE_DEVICE_HANDLE equ 24

EFI_SIMPLE_FS_OPEN_VOLUME   equ 8

EFI_FILE_OPEN               equ 8
EFI_FILE_CLOSE              equ 16
EFI_FILE_READ               equ 32


; ============================================================
; Llamadas UEFI con Microsoft x64 ABI
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


%macro EFI_CALL5 2
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 48
    mov qword [rsp + 32], %2
    call %1
    mov rsp, rbp
    pop rbp
%endmacro


%macro EFI_CALL6 3
    push rbp
    mov rbp, rsp
    and rsp, -16
    sub rsp, 48
    mov qword [rsp + 32], %2
    mov qword [rsp + 40], %3
    call %1
    mov rsp, rbp
    pop rbp
%endmacro


section .text


; ============================================================
; Punto de entrada
;
; RCX = EFI_HANDLE de este cargador
; RDX = EFI_SYSTEM_TABLE *
; ============================================================

efi_main:
    mov [rel image_handle], rcx
    mov [rel system_table], rdx

    mov rax, [rdx + EFI_ST_BOOT_SERVICES]
    mov [rel boot_services], rax

    lea rcx, [rel msg_loading]
    call print_string

    call load_clock_image
    test rax, rax
    js .load_failed

    ; LoadImage ya copio y reubico el PE/COFF, por lo que el
    ; buffer usado para leer el archivo puede liberarse ahora.
    call release_app_buffer

    lea rcx, [rel msg_starting]
    call print_string

    ; El Boot Manager puede dejar un watchdog activo. Un reloj
    ; interactivo puede permanecer abierto mas de cinco minutos,
    ; por lo que se deshabilita antes de iniciar la aplicacion.
    call disable_watchdog

    ; Pausa breve para que el mensaje del cargador sea visible.
    call loader_delay

    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_START_IMAGE]

    mov rcx, [rel child_image_handle]
    xor edx, edx
    xor r8d, r8d

    EFI_CALL rax

    mov [rel last_status], rax

    ; Una aplicacion UEFI se descarga automaticamente cuando
    ; retorna de su punto de entrada.
    mov qword [rel child_image_handle], 0

    mov rax, [rel last_status]
    test rax, rax
    js .application_failed

    lea rcx, [rel msg_returned]
    call print_string

    xor eax, eax
    ret


.load_failed:
    mov [rel last_status], rax

    call close_file_handles
    call unload_child_image
    call release_app_buffer

    lea rcx, [rel msg_load_failed]
    call print_string

    mov rax, [rel last_status]
    ret


.application_failed:
    lea rcx, [rel msg_application_failed]
    call print_string

    mov rax, [rel last_status]
    ret


; ============================================================
; load_clock_image
;
; 1. Obtiene el dispositivo desde el Loaded Image Protocol.
; 2. Abre el Simple File System de ese dispositivo.
; 3. Lee EFI/CLOCK/CLOCK.EFI en memoria.
; 4. Solicita al firmware cargar el PE/COFF con LoadImage().
;
; Retorna EFI_STATUS en RAX.
; ============================================================

load_clock_image:
    ; Obtener EFI_LOADED_IMAGE_PROTOCOL para este ejecutable.
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_HANDLE_PROTOCOL]

    mov rcx, [rel image_handle]
    lea rdx, [rel loaded_image_protocol_guid]
    lea r8, [rel loaded_image_protocol]

    EFI_CALL rax

    test rax, rax
    js .return

    mov r10, [rel loaded_image_protocol]
    test r10, r10
    jz .not_found

    mov rcx, [r10 + EFI_LOADED_IMAGE_DEVICE_HANDLE]
    test rcx, rcx
    jz .not_found

    ; Obtener EFI_SIMPLE_FILE_SYSTEM_PROTOCOL en el mismo medio.
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_HANDLE_PROTOCOL]

    lea rdx, [rel simple_file_system_protocol_guid]
    lea r8, [rel simple_file_system]

    EFI_CALL rax

    test rax, rax
    js .return

    ; Abrir el directorio raiz del volumen.
    mov rcx, [rel simple_file_system]
    test rcx, rcx
    jz .not_found

    mov rax, [rcx + EFI_SIMPLE_FS_OPEN_VOLUME]
    lea rdx, [rel root_handle]

    EFI_CALL rax

    test rax, rax
    js .return

    ; Abrir \EFI\CLOCK\CLOCK.EFI en modo lectura.
    mov rcx, [rel root_handle]
    mov rax, [rcx + EFI_FILE_OPEN]

    lea rdx, [rel app_file_handle]
    lea r8, [rel app_path]
    mov r9, EFI_FILE_MODE_READ
    xor r10d, r10d

    EFI_CALL5 rax, r10

    test rax, rax
    js .cleanup_error

    ; Reservar memoria temporal para el archivo PE/COFF.
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_ALLOCATE_POOL]

    mov ecx, EFI_LOADER_DATA
    mov edx, APP_BUFFER_SIZE
    lea r8, [rel app_buffer]

    EFI_CALL rax

    test rax, rax
    js .cleanup_error

    ; Read() actualiza app_buffer_size con los bytes leidos.
    mov qword [rel app_buffer_size], APP_BUFFER_SIZE

    mov rcx, [rel app_file_handle]
    mov rax, [rcx + EFI_FILE_READ]

    lea rdx, [rel app_buffer_size]
    mov r8, [rel app_buffer]

    EFI_CALL rax

    test rax, rax
    js .cleanup_error

    cmp qword [rel app_buffer_size], 0
    je .empty_file

    call close_file_handles

    ; LoadImage(FALSE, parent, NULL, buffer, size, &child).
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_LOAD_IMAGE]

    xor ecx, ecx
    mov rdx, [rel image_handle]
    xor r8d, r8d
    mov r9, [rel app_buffer]
    mov r10, [rel app_buffer_size]
    lea r11, [rel child_image_handle]

    EFI_CALL6 rax, r10, r11

.return:
    ret


.not_found:
    mov rax, EFI_NOT_FOUND
    ret


.empty_file:
    mov rax, EFI_LOAD_ERROR


.cleanup_error:
    mov [rel last_status], rax
    call close_file_handles
    call release_app_buffer
    mov rax, [rel last_status]
    ret


; ============================================================
; Cierre de archivos abiertos
; ============================================================

close_file_handles:
    mov rcx, [rel app_file_handle]
    test rcx, rcx
    jz .close_root

    mov rax, [rcx + EFI_FILE_CLOSE]
    EFI_CALL rax

    mov qword [rel app_file_handle], 0

.close_root:
    mov rcx, [rel root_handle]
    test rcx, rcx
    jz .done

    mov rax, [rcx + EFI_FILE_CLOSE]
    EFI_CALL rax

    mov qword [rel root_handle], 0

.done:
    ret


; ============================================================
; Liberar el buffer temporal utilizado para leer CLOCK.EFI
; ============================================================

release_app_buffer:
    mov rcx, [rel app_buffer]
    test rcx, rcx
    jz .done

    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_FREE_POOL]

    EFI_CALL rax

    mov qword [rel app_buffer], 0

.done:
    ret


; ============================================================
; Descargar una imagen que LoadImage creo pero que no se inicio
; ============================================================

unload_child_image:
    mov rcx, [rel child_image_handle]
    test rcx, rcx
    jz .done

    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_UNLOAD_IMAGE]

    EFI_CALL rax

    mov qword [rel child_image_handle], 0

.done:
    ret


; ============================================================
; Deshabilitar watchdog del Boot Manager
; ============================================================

disable_watchdog:
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_SET_WATCHDOG_TIMER]

    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d

    EFI_CALL rax
    ret


; ============================================================
; Pausa de un segundo mediante Boot Services Stall()
; ============================================================

loader_delay:
    mov rax, [rel boot_services]
    mov rax, [rax + EFI_BS_STALL]

    mov ecx, 1000000

    EFI_CALL rax
    ret


; ============================================================
; OutputString(ConOut, RCX)
; ============================================================

print_string:
    mov r10, rcx

    mov r11, [rel system_table]
    mov rcx, [r11 + EFI_ST_CON_OUT]
    mov rdx, r10

    mov rax, [rcx + EFI_CONOUT_OUTPUT_STRING]
    EFI_CALL rax
    ret


section .data

align 8

; EFI_LOADED_IMAGE_PROTOCOL_GUID
loaded_image_protocol_guid:
    dd 0x5B1B31A1
    dw 0x9562
    dw 0x11D2
    db 0x8E, 0x3F, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B

; EFI_SIMPLE_FILE_SYSTEM_PROTOCOL_GUID
simple_file_system_protocol_guid:
    dd 0x964E5B22
    dw 0x6459
    dw 0x11D2
    db 0x8E, 0x39, 0x00, 0xA0, 0xC9, 0x69, 0x72, 0x3B


; Ruta UTF-16: \EFI\CLOCK\CLOCK.EFI
app_path:
    dw 0x005C
    dw 'E', 'F', 'I'
    dw 0x005C
    dw 'C', 'L', 'O', 'C', 'K'
    dw 0x005C
    dw 'C', 'L', 'O', 'C', 'K', '.', 'E', 'F', 'I'
    dw 0


msg_loading:
    dw __utf16__(`Bootloader UEFI: cargando el reloj...\r\n`), 0

msg_starting:
    dw __utf16__(`Aplicacion encontrada. Iniciando...\r\n`), 0

msg_returned:
    dw __utf16__(`\r\nEl reloj regreso correctamente al firmware.\r\n`), 0

msg_load_failed:
    dw __utf16__(`ERROR: no se pudo cargar EFI\\CLOCK\\CLOCK.EFI.\r\n`), 0

msg_application_failed:
    dw __utf16__(`\r\nERROR: la aplicacion UEFI retorno un error.\r\n`), 0


section .bss

align 8

image_handle:           resq 1
system_table:           resq 1
boot_services:          resq 1

loaded_image_protocol:  resq 1
simple_file_system:     resq 1
root_handle:            resq 1
app_file_handle:        resq 1

app_buffer:             resq 1
app_buffer_size:        resq 1
child_image_handle:     resq 1

last_status:            resq 1
