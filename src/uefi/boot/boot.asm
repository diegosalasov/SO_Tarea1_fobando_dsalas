[BITS 16]
[ORG 0x7C00]

start:
    ; Your code here

    jmp $

times 510-($-$$) db 0
dw 0xAA55