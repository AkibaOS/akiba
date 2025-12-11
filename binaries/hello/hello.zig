const invocations = struct {
    const AI_EXIT: u64 = 0x01;

    fn exit(code: u64) noreturn {
        asm volatile (
            \\syscall
            :
            : [exit] "{rax}" (AI_EXIT),
              [code] "{rdi}" (code),
            : .{ .rcx = true, .r11 = true });
        unreachable;
    }
};

export fn _start() noreturn {
    // Exit with code 42
    invocations.exit(42);
}
