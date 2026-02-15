//! nav - Navigate the filesystem

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const sys = @import("sys");

var location_buf: [256]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    if (pc <= 1) {
        const location = io.getlocation(&location_buf) catch {
            format.colorln("nav: cannot get current location.", colors.red);
            return 1;
        };
        format.colorln(location, colors.green);
        return 0;
    }

    const arg = pv[1];
    var target_len: usize = 0;
    while (arg[target_len] != 0) : (target_len += 1) {}
    const target = arg[0..target_len];

    io.setlocation(target) catch {
        format.color("nav: cannot navigate to '", colors.red);
        format.print(target);
        format.colorln("': No such stack.", colors.red);
        return 1;
    };

    return 0;
}
