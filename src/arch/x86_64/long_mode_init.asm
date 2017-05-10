global long_mode_start          ; export name
extern rust_main

section .text
bits 64
long_mode_start:
        ; load 0 into all data segment registers
        mov ax, 0
        mov ss, ax
        mov ds, ax
        mov es, ax
        mov fs, ax
        mov gs, ax

        ; call the rust main (kernel entry point)
        call rust_main
        
        ; print 'OKAY' to screeen
        mov rax, 0x2f592f412f4b2f4f
        mov qword [0xb8000], rax
        hlt
