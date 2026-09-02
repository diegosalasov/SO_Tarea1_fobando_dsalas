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
; 0x08       8      OutputString
; 0x10       8      TestString
; 0x18       8      QueryMode
; 0x20       8      SetMode
; 0x28       8      SetAttribute
; 0x30       8      ClearScreen
; 0x38       8      SetCursorPosition
; 0x40       8      EnableCursor
; 0x48       8      *Mode


;        ______________________________________________________
;_______/ Constants section

; Protocols & Services
EFI_TEXT_OUTPUT      equ 0x40
EFI_BOOT_SERVICES    equ 0x60

; Functions
COUT_OUTPUT_STRING   equ 0x08

BS_LOCATE_HANDLE_BUF equ 0x138
BS_HANDLE_PROTOCOL   equ 0x98
BS_ALLOCATE_POOL     equ 0x40

FS_OPEN_VOLUME       equ 0x08

FILE_OPEN_MODE       equ 0x08
FILE_READ_MODE       equ 0x20

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
    mov r12, [SYSTEM_TABLE]            ; R12 = SystemTable
    mov r13, [r12 + EFI_BOOT_SERVICES] ; R13 = BootServices

    ; (1) Locate the filesystem handle
    ; [SystemTable -> BootServices -> LocateHandleBuffer]
    mov rax, [r13 + BS_LOCATE_HANDLE_BUF] ; RAX = LocateHandleBuffer

    sub rsp, 40

    mov rcx, 2                              ; RCX = SearchType [ByProtocol]
    lea rdx, [rel SimpleFileSystemGuid]     ; RDX = Protocol GUID
    lea r9,  [rel HandleCount]              ; R9 = NumberOfHandles *
    lea r8,  [rel HandleBuffer]
    mov qword [rsp + 32], r8                ; Buffer **
    xor r8, r8                              ; R8  = SearchKey [NULL]

    call rax        ; call LocateHandleBuffer(SearchType, GUID, SearchKey, NoHandles, Buffer)
    add rsp, 40

    test rax, rax   ; EFI_SUCCESS = 0
    jz  .filesystem_handle_continue
    .filesystem_handle_error:
        lea rcx, [rel fsh_err]; RCX = string addr
        call print_string     ; call PrintString(message)
        jmp $
    .filesystem_handle_continue:
    ; (2) Get the filesystem handle
    ; [HandleBuffer -> SimpleFileSystem]
    mov rbx, [rel HandleBuffer]         ; SimpleFileSystemHandle <- pointer to start of the handle buffer

    ; (3) Get the SimpleFileSystem protocol
    ; [SystemTable -> BootServices -> HandleProtocol]
    mov rax, [r13 + BS_HANDLE_PROTOCOL] ; RAX = HandleProtocol 

    mov rcx, [rbx]                      ; RCX = Handle          <- actual first element of the handle buffer
    lea rdx, [rel SimpleFileSystemGuid] ; RDX = Protocol GUID
    lea r8,  [rel FileSystem]           ; R8  = Interface **

    call rax        ; call HandleProtocol()

    test rax, rax   ; EFI_SUCCESS = 0
    jz  .filesystem_protocol_continue
    .filesystem_protocol_error:
        lea rcx, [rel fsp_err]; RCX = string addr
        call print_string     ; call PrintString(message)
        jmp $
    .filesystem_protocol_continue:
    ; (4) Use filesystem to open volume and open/read file

    ; > Open volume
    ; [SimpleFileSystem -> OpenVolume]
    mov rbx, [rel FileSystem]        ; SimpleFileSystemProtocol

    mov rax, [rbx + FS_OPEN_VOLUME]  ; RAX = OpenVolume

    mov rcx, rbx                 ; RCX = FileSystem
    lea rdx, [rel RootDirectory] ; RDX = Root **

    call rax       ; call OpenVolume()

    test rax, rax  ; EFI_SUCCESS = 0
    jz  .filesystem_volume_continue
    .filesystem_volume_error:
        lea rcx, [rel fsv_err]; RCX = string addr
        call print_string     ; call PrintString(message)
        jmp $
    .filesystem_volume_continue:
    ; > Open file (program)
    ; [FileProtocol -> OpenMode]
    mov rbx, [rel RootDirectory]    ; FileProtocol

    mov rax, [rbx + FILE_OPEN_MODE] ; RAX = FileOpen

    sub rsp, 40

    mov rcx, rbx                ; RCX = Root     
    lea rdx, [rel ClockFile]    ; RDX = FileHandle **
    lea r8,  [rel ClockPath]    ; R8 = filename
    mov r9, 1                   ; R9 = OpenMode [EFI_FILE_MODE_READ]
    mov qword [rsp + 32], 1     ; FileAttribute = 1

    call rax       ; call FileOpen()
    add rsp, 40

    test rax, rax  ; EFI_SUCCESS = 0
    jz  .file_open_continue
    .file_open_error:
        lea rcx, [rel fileo_err]; RCX = string addr
        call print_string       ; call PrintString(message)
        jmp $
    .file_open_continue:
    ; > Allocate memory for program
    ; [SystemTable -> BootServices -> AllocatePool]
    mov rax, [r13 + BS_ALLOCATE_POOL] ; AllocatePool

    mov rcx, 1                  ; RCX = EfiLoaderCode [EFI_MEMORY_TYPE]
    mov rdx, [rel BufferSize]   ; RDX = Size
    lea r8,  [rel ClockBuffer]  ; R8  = **Buffer

    call rax        ; call AllocatePool()

    test rax, rax   ; EFI_SUCCESS = 0
    jz  .memory_alloc_continue
    .memory_alloc_error:
        lea rcx, [rel mem_alloc_err]; RCX = string addr
        call print_string           ; call PrintString(message)
        jmp $
    .memory_alloc_continue:
    ; > Read file (program)
    ; [FileProtocol -> ReadMode]
    mov rax, [rbx + FILE_READ_MODE] ; FileRead

    mov rcx, [rel ClockFile]   ; RCX = FileHandle
    lea rdx, [rel BufferSize]  ; RDX = &BufferSize
    mov r8,  [rel ClockBuffer] ; R8  = *Buffer

    call rax        ; call FileRead()

    test rax, rax   ; EFI_SUCCESS = 0
    jz  .file_read_continue
    .file_read_error:
        lea rcx, [rel filer_err]; RCX = string addr
        call print_string       ; call PrintString(message)
        jmp $
    .file_read_continue:
    ; > Print success message
    lea rcx, [rel ext_msg] ; RCX = string addr
    call print_string      ; call PrintString(message)  

    ; (5) Call program
    add rsp, 32

    mov rax, [rel ClockBuffer] ; RAX = program entry point
    mov rcx, [IMAGE_HANDLE]    ; RCX = ImageHandle
    mov rdx, [SYSTEM_TABLE]    ; RDX = SystemTable

    call rax                   ; call program()
    sub rsp, 32
    ;---------------------------------------------------------
    ; If kernel/program returns print a message
    ;---------------------------------------------------------
    lea rcx, [rel end_msg] ; RCX = string addr
    call print_string      ; call PrintString(message)   

    ; end
    xor eax, eax            ; EFI_SUCCESS
    jmp $ ; infinite loop to prevent returning to UEFI shell
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
    call rax                ; call OutputString(ConOut, message)

    ; end
    ret

;        ______________________________________________________
;_______/ Data section
section .data
    ; > Message strings
    msg     dw __utf16__(`Bootloader running...\r\n`), 0
    sys_msg dw __utf16__(`Calling for kernel/program...\r\n`), 0
    ext_msg dw __utf16__(`[SUCESS] All kernel/program operations succeded\r\n`), 0
    end_msg dw __utf16__(`Returning to bootloader...\r\n`), 0

    fsh_err dw __utf16__(`[ERROR](SimpleFileSystem) Failure to get handle\r\n`), 0
    fsp_err dw __utf16__(`[ERROR](SimpleFileSystem) Failure to get protocol\r\n`), 0
    fsv_err dw __utf16__(`[ERROR](SimpleFileSystem) Failure to open volume\r\n`), 0

    fileo_err dw __utf16__(`[ERROR](File) Failure to open\r\n`), 0
    filer_err dw __utf16__(`[ERROR](File) Failure to read\r\n`), 0

    mem_alloc_err dw __utf16__(`[ERROR](MemoryAllocate) Failure to allocate memory\r\n`), 0

    ; > EFI Simple File System GUID
    SimpleFileSystemGuid:
        dd 0x0964e5b22
        dw 0x6459
        dw 0x11D2
        db 0x8E,0x39,0x00,0xA0,0xC9,0x69,0x72,0x3B

    ; > File paths
    ClockPath dw __utf16__(`app.bin`), 0

    ; > Variables
    HandleCount     dq 0   ; number of handles in buffer
    HandleBuffer    dq 0  ; address of handle buffer for LocateHandleBuffer()
    FileSystem      dq 0    ; address of Simple File System protocol
    RootDirectory   dq 0 ; address of root directory (FileProtocol) handle
    ClockFile       dq 0     ; address of file handle
    ClockBuffer     dq 0   ; address of buffer
    BufferSize      dq 1024 ; size in bytes (1024 bytes = 1 kB)

section .bss
    ; > Global EFI attributes (64-bit)
    IMAGE_HANDLE resq 1 ; EFI_HANDLE       -> ImageHandle (entry point)
    SYSTEM_TABLE resq 1 ; EFI_SYSTEM_TABLE -> EFI system table for protocols & services (entry point)