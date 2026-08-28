; Lector de sectores CHS mediante servicios BIOS.
;
; Entrada:
;   ES:BX = destino
;   AL    = cantidad de sectores
;   DL    = unidad
;   CH/CL = cilindro/sector
;   DH    = cabeza
read_sector:
    mov ah, 0x02
    int 0x13

    jc .fail

    ret

.fail:
    mov si, read_error_msg
    call printf
    jmp $

read_error_msg:
    db "Disk Read Error", 0
