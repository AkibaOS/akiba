const akiba = @import("akiba");

export fn _start() noreturn {
    const path = "/system/test/test.txt";

    const fd = akiba.io.attach(path, akiba.io.VIEW_ONLY) catch {
        _ = akiba.io.mark(akiba.io.trace, "Error: Cannot open file\n") catch 0;
        akiba.kata.exit(1);
    };

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes = akiba.io.view(fd, &buffer) catch break;
        if (bytes == 0) break;
        _ = akiba.io.mark(akiba.io.stream, buffer[0..bytes]) catch 0;
    }

    akiba.io.seal(fd);
    akiba.kata.exit(0);
}
