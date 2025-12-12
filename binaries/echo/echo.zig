//! Echo - Simple test program that writes to Stream device

const invocations = struct {
    const EXIT: u64 = 0x01;
    const ATTACH: u64 = 0x02;
    const SEAL: u64 = 0x03;
    const VIEW: u64 = 0x04;
    const MARK: u64 = 0x05;

    fn exit(code: u64) noreturn {
        asm volatile (
            \\mov %[exit], %%rax
            \\mov %[code], %%rdi
            \\syscall
            :
            : [exit] "r" (EXIT),
              [code] "r" (code),
            : .{ .rax = true, .rdi = true });
        unreachable;
    }

    fn mark(fd: u64, buffer: [*]const u8, count: u64) u64 {
        return asm volatile (
            \\mov %[mark], %%rax
            \\mov %[fd], %%rdi
            \\mov %[buffer], %%rsi
            \\mov %[count], %%rdx
            \\syscall
            : [ret] "={rax}" (-> u64),
            : [mark] "r" (MARK),
              [fd] "r" (fd),
              [buffer] "r" (buffer),
              [count] "r" (count),
            : .{ .rax = true, .rdi = true, .rsi = true, .rdx = true, .rcx = true, .r11 = true });
    }
};

export fn _start() noreturn {
    // Write to stream (fd 1 = /system/devices/stream)
    const message = "Hello from Echo!\n";
    const bytes_written = invocations.mark(1, message.ptr, message.len);

    // Exit with the number of bytes written
    invocations.exit(bytes_written);
}
