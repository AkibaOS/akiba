//! wipe - Clear the terminal screen

const akiba = @import("akiba");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;
    akiba.io.wipe();
    return 0;
}
