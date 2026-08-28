; Simple boot loader disk sector reader via interrupts
read_sector:
    ; Prerequisites: ES:BX (dest), DL (drive), CH/DH/CL (CHS)
    mov ah, 0x02    ; function: read sectors
    mov al, 0x01    ; number of sectors
    int 0x13        ; interrupt: disk services
    jc .fail        ; Jump if Carry Flag (CF) is set (failure)
    ret

.fail:
    mov si, read_error_msg
    call printf
    jmp $           ; Halt forever on error

read_error_msg db "Disk Read Error", 0