#![feature(lang_items)]
#![feature(const_fn)]
#![feature(unique)]
#![feature(alloc, collections)]
#![feature(abi_x86_interrupt)]

#![no_std]

extern crate rlibc;
extern crate volatile;
extern crate spin;
extern crate multiboot2;
#[macro_use]
extern crate bitflags;
extern crate x86_64;

extern crate hole_list_allocator;
extern crate alloc;
#[macro_use]
extern crate collections;
#[macro_use]
extern crate once;
#[macro_use]
extern crate lazy_static;
extern crate bit_field;

#[macro_use]
mod vga_buffer;
mod memory;
mod interrupts;

#[no_mangle]
pub extern fn rust_main(multiboot_information_address: usize) {
    // ATTENTION: we have a very small stack and no guard page
    vga_buffer::clear_screen();
    println!("Hello World{}", "!");

    let boot_info = unsafe { multiboot2::load(multiboot_information_address) };
    enable_nxe_bit();
    enable_write_protect_bit();

    // set up guard page and map the heap pages
    let mut memory_controller = memory::init(boot_info);

    // initialize our IDT
    interrupts::init(&mut memory_controller);

    fn stack_overflow() {
        stack_overflow();
    }

    // trigger a stack overflow
    stack_overflow();

    println!("It didn't crash!");

    loop{}
}

fn enable_nxe_bit() {
    use x86_64::registers::msr::{IA32_EFER, rdmsr, wrmsr};

    let nxe_bit = 1 << 11;
    unsafe {
        let efer = rdmsr(IA32_EFER);
        wrmsr(IA32_EFER, efer | nxe_bit);
    }
}

fn enable_write_protect_bit() {
    use x86_64::registers::control_regs::{cr0, cr0_write, Cr0};
    unsafe {
        cr0_write(cr0() | Cr0::WRITE_PROTECT)
    };
}

#[lang = "eh_personality"] extern fn eh_personality() {}

#[lang = "panic_fmt"]
#[no_mangle]
pub extern fn panic_fmt(fmt: core::fmt::Arguments, file: &'static str,
                        line: u32) -> !
{
    println!("\n\nPANIC in {} at line {}:", file, line);
    println!("    {}", fmt);
    loop{}
}
