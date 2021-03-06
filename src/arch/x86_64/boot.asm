global start                    ; Make start the kernel entry point!
extern long_mode_start          ; Defined elsewhere

section .text
bits 32
start:
        mov esp, stack_top      ; Update the stack pointer
        mov edi, ebx            ; Move multiboot info pointer to edi

        call check_multiboot
        call check_cpuid
        call check_long_mode

        call setup_page_tables
        call enable_paging

        lgdt [gdt64.pointer]
        jmp gdt64.code:long_mode_start

        ; Print 'OK' to the screen
        mov dword [0xb8000], 0x2f4b2f4f
        hlt

check_multiboot:
        cmp eax, 0x36d76289
        jne .no_multiboot
        ret
.no_multiboot:
        mov al, "0"
        jmp error
        
; Copied from OSDev Wiki
check_cpuid:
        ; Check if CPUID is supported by attempting to flip the ID bit (bit 21)
        ; in the FLAGS register. If we can flip it, CPUID is available.
        
        ; Copy FLAGS in to EAX via stack
        pushfd
        pop eax
        
        ; Copy to ECX as well for comparing later on
        mov ecx, eax
        
        ; Flip the ID bit
        xor eax, 1 << 21
        
        ; Copy EAX to FLAGS via the stack
        push eax
        popfd
        
        ; Copy FLAGS back to EAX (with the flipped bit if CPUID is supported)
        pushfd
        pop eax
        
        ; Restore FLAGS from the old version stored in ECX (i.e. flipping the
        ; ID bit back if it was ever flipped).
        push ecx
        popfd
        
        ; Compare EAX and ECX. If they are equal then that means the bit
        ; wasn't flipped, and CPUID isn't supported.
        cmp eax, ecx
        je .no_cpuid
        ret
.no_cpuid:
        mov al, "1"
        jmp error

; Copied from OSDev Wiki
check_long_mode:
        ; test if extended processor info in available
        mov eax, 0x80000000     ; implicit argument for cpuid
        cpuid                   ; get highest supported argument
        cmp eax, 0x80000001     ; it needs to be at least 0x80000001
        jb .no_long_mode        ; if it's less, the CPU is too old for long mode
        
        ; use extended info to test if long mode is available
        mov eax, 0x80000001     ; argument for extended processor info
        cpuid                   ; returns various feature bits in ecx and edx
        test edx, 1 << 29       ; test if the LM-bit is set in the D-register
        jz .no_long_mode        ; If it's not set, there is no long mode
        ret
.no_long_mode:
        mov al, "2"
        jmp error
        
setup_page_tables:
        ; setup recursive mapping (511th P4 entry points to itself)
        mov eax, p4_table
        or eax, 0b11            ; present + writable
        mov [p4_table + 511 * 8], eax
        ; map the first P4 entry to P3 table
        mov eax, p3_table
        or eax, 0b11            ; present + writable
        mov [p4_table], eax

        ; map the first P3 entry to P2 table
        mov eax, p2_table
        or eax, 0b11
        mov [p3_table], eax

        ; map eaxh P2 entry to a huge 2MiB page
        mov ecx, 0

.map_p2_table:
        ; map ecx-th P2 entry to a huge page that starts at address 2MiB * ecx
        mov eax, 0x200000       ; 2MiB
        mul ecx                 ; calculate start address from index
        or eax, 0b10000011      ; present + writable + huge
        mov [p2_table + ecx * 8], eax ; map entry

        inc ecx                 ; bump counter
        cmp ecx, 512            ; if ecx <= 511, repeat
        jne .map_p2_table       ; loop

        ret

enable_paging:
        ; load P4 to cr3 register (which cpu uses to access P4 table)
        mov eax, p4_table
        mov cr3, eax

        ; enable PAE-flag in cr4
        mov eax, cr4
        or eax, 1 << 5
        mov cr4, eax

        ; set long mode bit in EFER Model Specific Register (MSR)
        mov ecx, 0xc0000080
        rdmsr
        or eax, 1 << 8
        wrmsr

        ; enable paging in the cr0 register
        mov eax, cr0
        or eax, 1 << 31
        mov cr0, eax

        ret

; This function prints 'ERR: ' followed by the
; given error code and hangs. 
; parameter: error code (in ascii) in al
error:
        mov dword [0xb8000], 0x4f524f45
        mov dword [0xb8004], 0x4f3a4f52
        mov dword [0xb8008], 0x4f204f20
        mov byte  [0xb800a], al
        hlt

section .rodata
gdt64:
        dq 0                    ; 0 entry
.code: equ $ - gdt64
        dq (1 << 43) | (1 << 44) | (1 << 47) | (1 << 53) ; code segment
.pointer:
        dw $ - gdt64 - 1
        dq gdt64
        
section .bss
align 4096
p4_table:
        resb 4096
p3_table:
        resb 4096
p2_table:
        resb 4096
stack_bottom:
        resb 4096 * 4           ; 4 pages (16kB)
stack_top:
