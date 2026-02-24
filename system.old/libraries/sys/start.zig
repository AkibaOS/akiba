//! Entry point

extern fn main(pc: u32, pv: [*]const [*:0]const u8) u8;

export fn _start() callconv(.naked) noreturn {
    asm volatile (
        \\mov (%%rsp), %%edi
        \\mov 8(%%rsp), %%rsi
        \\and $-16, %%rsp
        \\call main
        \\movzbl %%al, %%edi
        \\mov $0x01, %%eax
        \\syscall
        \\ud2
    );
}
