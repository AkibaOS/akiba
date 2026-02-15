//! rd - Read unit contents

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const sys = @import("sys");

var file_buffer: [64 * 1024]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    if (pc <= 1) {
        format.colorln("rd: missing unit location.", colors.red);
        return 1;
    }

    const arg = pv[1];
    var location_len: usize = 0;
    while (arg[location_len] != 0) : (location_len += 1) {}
    const location = arg[0..location_len];

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
