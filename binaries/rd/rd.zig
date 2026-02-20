//! rd - Read unit contents

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const params = @import("params");
const sys = @import("sys");

var file_buffer: [64 * 1024]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    const p = params.parse(pc, pv) catch |err| {
        format.color("rd: ", colors.red);
        format.println(@errorName(err));
        return 1;
    };

    if (p.positionals.len == 0) {
        format.colorln("rd: missing unit location.", colors.red);
        return 1;
    }

    if (p.positionals.len > 1) {
        format.colorln("rd: invalid number of positional parameters.", colors.red);
        return 1;
    }

    if (p.named.len > 0) {
        format.colorln("rd: named parameters are not supported.", colors.red);
        return 1;
    }

    const location = switch (p.positional(0).?) {
        .scalar => |s| s,
        .list => {
            format.colorln("rd: only one location allowed", colors.red);
            return 1;
        },
    };

    const fd = io.attach(location, io.VIEW_ONLY) catch {
        format.color("rd: cannot access '", colors.red);
        format.print(location);
        format.colorln("': No such unit.", colors.red);
        return 1;
    };

    const bytes_read = io.view(fd, &file_buffer) catch {
        format.color("rd: cannot read '", colors.red);
        format.print(location);
        format.colorln("'.", colors.red);
        io.seal(fd);
        return 1;
    };

    if (bytes_read > 0) {
        format.print(file_buffer[0..bytes_read]);

        if (file_buffer[bytes_read - 1] != '\n') {
            format.print("\n");
        }
    }

    io.seal(fd);

    return 0;
}
