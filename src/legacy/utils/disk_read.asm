; Simple bootloader disk reader via interrupts
; Requires <print.asm> for basic print functionalities
; ---------------------------------------------------------------------

; Read sectors from disk with CHS configuration
; disk_read(dest[ES:BX], sectors[AL], drive[DL], cylinder[CH], head[DH], sector[CL])
; @params:
; ES => destination segment (16 bits)
; BX => destination offset  (16 bits)
; AL => number of sectors   (8 bits )
; DL => drive number        (8 bits ) [floppy disk = 0x00, drive = 0x80]
; CH => cylinder number     (8 bits ) 0-based
; DH => head number         (8 bits ) 0-based
; CL => sector number       (8 bits ) 1-based
disk_read:
    mov ah, 0x02    ; function: read sectors
    int 0x13        ; interrupt: disk services
    jc .fail        ; Jump if Carry Flag (CF) is set (failure)
    ret

.fail:
    mov si, read_error_msg
    call print_s
    jmp $           ; Halt forever on error

read_error_msg db "ERROR: (Disk Read) Failed to access drive", 0x0D, 0x0A, 0