section .multiboot_header
header_start:
        dd 0xe85250d6           ; magic number for multiboot 2
        dd 0                    ; denotes x86
        dd header_end - header_start ; header length
        ; The next line is a checksum. the constant is a hack for the compiler
        dd 0x100000000 - (0xe85250d6 + 0 + (header_end - header_start))

        ; Optional Multiboot tags

        ; End tag
        dw 0
        dw 0
        dd 8

header_end:
