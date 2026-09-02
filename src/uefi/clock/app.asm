[BITS 64]
default rel

;        ______________________________________________________
;_______/ Constants section

; Protocols & Services
EFI_TEXT_OUTPUT      equ 0x40

; Functions
COUT_OUTPUT_STRING   equ 0x08

;        ______________________________________________________
;_______/ Code section
section .text

; Entry point for program
; RCX = EFI_HANDLE ImageHandle
; RDX = EFI_SYSTEM_TABLE SystemTable
app:
    ;start
    mov qword [rel IMAGE_HANDLE], rcx  ; save ImageHandle
    mov qword [rel SYSTEM_TABLE], rdx  ; save SystemTable
    ;print message
    lea rcx, [rel message]          ; RCX = message address
    call print_string               ; call PrintString(message)
    ;end
    ret

; PrintString(*str): string must be utf-16
; [SystemTable -> ConOut -> OutputString]
; RCX = string addr
print_string:
    ; start
    push rcx
    mov r8, [SYSTEM_TABLE]  ; R8  = SystemTable
    
    mov rcx, [r8 + EFI_TEXT_OUTPUT]    ; RCX = ConOut [at offset 0x40]
    pop rdx                            ; RDX = string address
    
    mov rax, [rcx + COUT_OUTPUT_STRING]; RAX = OutputString [at offset 0x08]
    call rax   ; call OutputString(ConOut, message)

    ; end
    ret

;        ______________________________________________________
;_______/ Data section
section .bss
    IMAGE_HANDLE resq 1 ; EFI_HANDLE       -> ImageHandle (entry point)
    SYSTEM_TABLE resq 1 ; EFI_SYSTEM_TABLE -> EFI system table for protocols & services (entry point)

section .data
    message dw __utf16__(`Running program/kernel...\r\n`), 0

; Fill the rest of the 512 bytes with zeros
times 512-($-$$) db 0 ; padding