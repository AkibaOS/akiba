//! wipe - Clear the terminal screen

const colors = @import("colors");
const format = @import("format");
const io = @import("io");
const params = @import("params");
const sys = @import("sys");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    const p = params.parse(pc, pv) catch return 1;

    if (p.positionals.len > 0) {
        format.colorln("wipe: positional parameters are not supported.", colors.red);
        return 1;
    }

    if (p.named.len > 0) {
        format.colorln("wipe: named parameters are not supported.", colors.red);
        return 1;
    }

    io.wipe();
    return 0;
}
