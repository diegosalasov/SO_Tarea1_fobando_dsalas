; ============================================================
; rtc.asm
;
; Hora real mediante EFI_RUNTIME_SERVICES.GetTime()
; ============================================================


section .data


rtc_hour:
    db 0

rtc_minute:
    db 0

rtc_second:
    db 0

rtc_available:
    db 0

rtc_last_second:
    db 0xFF


efi_time:
    times EFI_TIME_SIZE db 0


section .text


; ============================================================
; rtc_read_time
;
; CF = 0 -> lectura correcta
; CF = 1 -> error
; ============================================================

rtc_read_time:

    push rax
    push rcx
    push rdx
    push r10


    mov r10, [rel runtime_services]

    mov rax, [r10 + EFI_RT_GET_TIME]


    ; GetTime(
    ;     EFI_TIME *Time,
    ;     EFI_TIME_CAPABILITIES *Capabilities
    ; )

    lea rcx, [rel efi_time]

    xor rdx, rdx


    EFI_CALL rax


    test rax, rax
    jnz .error


    mov al, [rel efi_time + EFI_TIME_HOUR]
    mov [rel rtc_hour], al

    mov al, [rel efi_time + EFI_TIME_MINUTE]
    mov [rel rtc_minute], al

    mov al, [rel efi_time + EFI_TIME_SECOND]
    mov [rel rtc_second], al


    mov byte [rel rtc_available], 1


    pop r10
    pop rdx
    pop rcx
    pop rax

    clc

    ret


.error:

    mov byte [rel rtc_available], 0


    pop r10
    pop rdx
    pop rcx
    pop rax

    stc

    ret


; ============================================================
; rtc_print_2digits
;
; AL = numero binario entre 0 y 99
; ============================================================

rtc_print_2digits:

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
; rtc_print_time
;
; HH:MM:SS
; ============================================================

rtc_print_time:

    push rax


    mov al, [rel rtc_hour]
    call rtc_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [rel rtc_minute]
    call rtc_print_2digits


    mov al, ':'
    call video_print_char


    mov al, [rel rtc_second]
    call rtc_print_2digits


    pop rax

    ret