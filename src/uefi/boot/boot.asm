[BITS 64]
default rel

global efi_main
;        ______________________________________________________
;_______/ UEFI documentation

; Microsoft x64 calling convention
; RAX: return 
; RCX: parameter 1
; RDX: parameter 2
; R8:  parameter 3
; R9:  parameter 4

; EFI System Table
; offset    size    service/protocol
; ────────────────────────────────────────
; 0x00      24      EFI_TABLE_HEADER
; 0x18       8      FirmwareVendor
; 0x20       4      FirmwareRevision
; 0x24       4      padding
; 0x28       8      ConsoleInHandle
; 0x30       8      ConIn
; 0x38       8      ConsoleOutHandle
; 0x40       8      ConOut
; 0x48       8      StandardErrorHandle
; 0x50       8      StdErr
; 0x58       8      RuntimeServices
; 0x60       8      BootServices
; 0x68       8      NumberOfTableEntries
; 0x70       8      ConfigurationTable

; ConOut functions
; offset    size    function
; ────────────────────────────────────────
; 0x00       8      Reset
; 0x00       8      OutputString
; 0x00       8      TestString
; 0x00       8      QueryMode
; 0x00       8      SetMode
; 0x00       8      SetAttribute
; 0x00       8      ClearScreen
; 0x00       8      SetCursorPosition
; 0x00       8      EnableCursor
; 0x00       8      *Mode


;        ______________________________________________________
;_______/ Code section
section .text

; UEFI entry point -> bootloader code
; RCX = EFI_HANDLE ImageHandle
; RDX = EFI_SYSTEM_TABLE SystemTable
efi_main:
    ; start
    mov qword [IMAGE_HANDLE], rcx ; save ImageHandle
    mov qword [SYSTEM_TABLE], rdx ; save SystemTable

    ;---------------------------------------------------------
    ; Print a startup message
    ;---------------------------------------------------------
    ; [SystemTable -> ConOut(protocol) -> OutputString(function)]
    lea rcx, [rel msg]     ; RCX = string addr
    call print_string      ; call PrintString(message)  

    ;---------------------------------------------------------
    ; Print a message before calling kernel/program
    ;---------------------------------------------------------
    ; [SystemTable -> ConOut(protocol) -> OutputString(function)]
    lea rcx, [rel sys_msg] ; RCX = string addr
    call print_string      ; call PrintString(message)  

    ;---------------------------------------------------------
    ; Use EFI filesystem to load the .BIN file for kernel/program (hand-off)
    ;---------------------------------------------------------

    ; (1) Locate the filesystem handle
    ; [SystemTable -> BootServices -> LocateHandleBuffer]
    mov r8, [SYSTEM_TABLE]  ; R8

    ; (2) Get the filesystem handle
    ; [HandleBuffer -> SimpleFileSystem]

    ; (3) Get the SimpleFileSystem protocol
    ; [SystemTable -> BootServices -> HandleProtocol]

    ; (4) Use filesystem to open volume and open/read file

    ; > Open volume
    ; [SimpleFileSystem -> OpenVolume]

    ; > Open file (program)
    ; [FileProtocol -> OpenMode]

    ; > Allocate memory for program
    ; [SystemTable -> BootServices -> AllocatePool]

    ; > Read file (program) into allocated memory
    ; [FileProtocol -> ReadMode]

    ; (5) Call program


    ;---------------------------------------------------------
    ; If kernel/program returns print a message
    ;---------------------------------------------------------
    lea rcx, [rel end_msg] ; RCX = string addr
    call print_string      ; call PrintString(message)   

    ; end
    xor eax, eax            ; EFI_SUCCESS
    jmp  $ ; loop forever
    ret

; PrintString(*str): string must be utf-16
; [SystemTable -> ConOut -> OutputString]
; RCX = string addr
print_string:
    ; start
    mov rbx, rcx
    mov r8, [SYSTEM_TABLE]  ; R8  = SystemTable
    
    mov rcx, [r8 + 0x40]    ; RCX = ConOut [at offset 0x40]
    mov rdx, rbx            ; RDX = string address

    mov rax, [rcx + 0x08]   ; RAX = OutputString [at offset 0x08]
    call rax                ; call OutputString(ConOut, message)

    ; end
    ret

;        ______________________________________________________
;_______/ Data section
section .data
    ; > Message strings
    msg     dw __utf16__(`Bootloader running...\r\n`), 0
    sys_msg dw __utf16__(`Calling for kernel/program...\r\n`), 0
    end_msg dw __utf16__(`Back to bootloader...\r\n`)
section .bss
    ; > Global EFI attributes (64-bit)
    IMAGE_HANDLE resq 1 ; EFI_HANDLE       -> ImageHandle (entry point)
    SYSTEM_TABLE resq 1 ; EFI_SYSTEM_TABLE -> EFI system table for protocols & services (entry point)