//! Akiba Runtime Entry Point
//! Provides _start that calls user's main(pc, pv) and handles exit

const kata = @import("kata.zig");

// User must provide this
extern fn main(pc: u32, pv: [*]const [*:0]const u8) u8;

export fn _start() callconv(.c) noreturn {
    // Stack layout at entry:
    //   [RSP + 0]  = pc (parameter count)
    //   [RSP + 8]  = pv (pointer to parameter vector)

    const stack_ptr = asm volatile ("mov %%rsp, %[result]"
        : [result] "=r" (-> u64),
    );

    const pc: u32 = @intCast(@as(*const u64, @ptrFromInt(stack_ptr)).*);
    const pv: [*]const [*:0]const u8 = @ptrFromInt(@as(*const u64, @ptrFromInt(stack_ptr + 8)).*);

    const exit_code = main(pc, pv);

    kata.exit(exit_code);
}
