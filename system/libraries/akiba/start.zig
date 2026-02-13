//! Akiba Runtime Entry Point
//! Provides _start that calls user's main(pc, pv) and handles exit

// User must provide this
extern fn main(pc: u32, pv: [*]const [*:0]const u8) u8;

export fn _start() callconv(.naked) noreturn {
    // At entry, stack layout is:
    //   [RSP + 0]  = pc (parameter count, 64-bit but only low 32 used)
    //   [RSP + 8]  = pv (pointer to parameter vector)
    //
    // x86-64 calling convention:
    //   First arg (u32) -> EDI
    //   Second arg (ptr) -> RSI

    asm volatile (
    // Load arguments for main(pc, pv)
        \\mov (%%rsp), %%edi      
        \\mov 8(%%rsp), %%rsi     
        // Align stack to 16 bytes before call (required by ABI)
        \\and $-16, %%rsp
        \\call main
        // main returned exit code in AL, zero-extend to RDI for exit syscall
        \\movzbl %%al, %%edi
        // exit syscall (0x01)
        \\mov $0x01, %%eax
        \\syscall
        // Should never reach here
        \\ud2
    );
}
