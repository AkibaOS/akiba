//! wipe - Clear the terminal screen

const io = @import("io");
const sys = @import("sys");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;
    io.wipe();
    return 0;
}
