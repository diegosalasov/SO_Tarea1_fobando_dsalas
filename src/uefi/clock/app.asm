[BITS 64]
default rel

;        ______________________________________________________
;_______/ Code section
section .text

; Entry point for program
; RCX = EFI_HANDLE ImageHandle
; RDX = EFI_SYSTEM_TABLE SystemTable
app:
    ;start
    mov r8, rdx             ; R8 = SystemTable
    
    mov rcx, [r8 + 0x40]    ; RCX = ConOut
    lea rdx, [rel message]  ; RDX = string addr

    mov rax, [rcx + 0x08]   ; RAX = OutputString
    call rax                ; call OutputString(ConOut, message)
    ;end
    jmp $


;        ______________________________________________________
;_______/ Data section
section .data
    message dw __utf16__(`Hello World!`), 0

; Fill the rest of the 512 bytes with zeros
times 512-($-$$) db 0 ; padding