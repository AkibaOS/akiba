//! rd - Display file contents

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

    fn attach(path: [*:0]const u8, flags: u64) u64 {
        return asm volatile (
            \\mov %[attach], %%rax
            \\mov %[path], %%rdi
            \\mov %[flags], %%rsi
            \\syscall
            : [ret] "={rax}" (-> u64),
            : [attach] "r" (ATTACH),
              [path] "r" (path),
              [flags] "r" (flags),
            : .{ .rax = true, .rdi = true, .rsi = true, .rcx = true, .r11 = true });
    }

    fn seal(fd: u64) void {
        asm volatile (
            \\mov %[seal], %%rax
            \\mov %[fd], %%rdi
            \\syscall
            :
            : [seal] "r" (SEAL),
              [fd] "r" (fd),
            : .{ .rax = true, .rdi = true, .rcx = true, .r11 = true });
    }

    fn view(fd: u64, buffer: [*]u8, count: u64) u64 {
        return asm volatile (
            \\mov %[view], %%rax
            \\mov %[fd], %%rdi
            \\mov %[buffer], %%rsi
            \\mov %[count], %%rdx
            \\syscall
            : [ret] "={rax}" (-> u64),
            : [view] "r" (VIEW),
              [fd] "r" (fd),
              [buffer] "r" (buffer),
              [count] "r" (count),
            : .{ .rax = true, .rdi = true, .rsi = true, .rdx = true, .rcx = true, .r11 = true });
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

// Flags
const VIEW_ONLY: u64 = 0x01;

export fn _start() noreturn {
    // For now, hardcode a test file path
    // TODO: Get path from arguments
    const path = "/system/test/test.txt";

    // Open file
    const fd = invocations.attach(path, VIEW_ONLY);

    if (fd == @as(u64, @bitCast(@as(i64, -1)))) {
        // Failed to open
        const error_msg = "Error: Cannot open file\n";
        _ = invocations.mark(2, error_msg.ptr, error_msg.len); // stderr
        invocations.exit(1);
    }

    // Read and display file
    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = invocations.view(fd, &buffer, buffer.len);

        if (bytes_read == 0 or bytes_read == @as(u64, @bitCast(@as(i64, -1)))) {
            break;
        }

        _ = invocations.mark(1, &buffer, bytes_read); // stdout
    }

    // Close file
    invocations.seal(fd);

    invocations.exit(0);
}
