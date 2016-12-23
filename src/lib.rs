#![feature(lang_items)]
#![feature(const_fn)]
#![feature(unique)]
#![feature(asm)]
#![feature(naked_functions)]
#![feature(core_intrinsics)]
#![feature(alloc, collections)]
#![no_std]

extern crate rlibc;
extern crate volatile;
extern crate spin;
extern crate multiboot2;
extern crate x86;
extern crate alloc;
extern crate bit_field;
#[macro_use]
extern crate bitflags;
#[macro_use]
extern crate collections;
#[macro_use]
extern crate once;
#[macro_use]
extern crate lazy_static;

extern crate hole_list_allocator; // defined in libs

#[macro_use]
mod vga_buffer;
mod memory;
mod interrupts;

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn _Unwind_Resume() -> ! {
    loop{}
}

#[no_mangle]
pub extern fn rust_main(multiboot_information_address: usize) {
    vga_buffer::clear_screen();
    println!("Hello World{}", "!");

    let boot_info = unsafe{
        multiboot2::load(multiboot_information_address)
    };

    enable_nxe_bit();
    enable_write_protect_bit();

    memory::init(boot_info);

    // initialize our IDT
    interrupts::init();

    // provoke a page fault
    unsafe { *(0xdeadbeaf as *mut u64) = 42 };

    println!("It did not crash!");
    
    loop{}
}

fn enable_nxe_bit() {
    use x86::shared::msr::{IA32_EFER, rdmsr, wrmsr};

    let nxe_bit = 1 << 11;
    unsafe {
        let efer = rdmsr(IA32_EFER);
        wrmsr(IA32_EFER, efer | nxe_bit);
    }
}

fn enable_write_protect_bit() {
    use x86::shared::control_regs::{cr0, cr0_write, CR0_WRITE_PROTECT};

    unsafe { cr0_write(cr0() | CR0_WRITE_PROTECT) };
}

fn divide_by_zero() {
    unsafe {
        asm!("mov dx,0; div dx" ::: "ax", "dx" : "volatile", "intel")
    }
}

#[lang = "eh_personality"] extern fn eh_personality() {}
#[lang = "panic_fmt"] #[no_mangle] extern fn panic_fmt(fmt: core::fmt::Arguments,
                                                       file: &'static str,
                                                       line: u32) -> !
{
    println!("\n\nPANIC in {} at line {}:", file, line);
    println!("    {}", fmt);
    loop{}
}
