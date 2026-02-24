//! nav - Navigate the filesystem

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const params = @import("params");
const sys = @import("sys");

var location_buf: [256]u8 = undefined;

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    const p = params.parse(pc, pv) catch |err| {
        format.color("nav: ", colors.red);
        format.println(@errorName(err));
        return 1;
    };

    // No params - print current location
    if (p.positionals.len == 0) {
        const location = io.getlocation(&location_buf) catch {
            format.colorln("nav: cannot get current location.", colors.red);
            return 1;
        };
        format.colorln(location, colors.green);
        return 0;
    }

    if (p.positionals.len > 1) {
        format.colorln("nav: invalid number of positional parameters.", colors.red);
        return 1;
    }

    if (p.named.len > 0) {
        format.colorln("nav: named parameters are not supported.", colors.red);
        return 1;
    }

    // Get target from first positional
    const target = switch (p.positional(0).?) {
        .scalar => |s| s,
        .list => {
            format.colorln("nav: only one location allowed", colors.red);
            return 1;
        },
    };

    io.setlocation(target) catch {
        format.color("nav: cannot navigate to '", colors.red);
        format.print(target);
        format.colorln("': No such stack.", colors.red);
        return 1;
    };

    return 0;
}
