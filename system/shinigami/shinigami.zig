//! Shinigami - The Soul Reaper
//! Background service that reaps zombie katas

const kata = @import("kata");

export fn main(pc: u32, pv: [*]const [*:0]const u8) u8 {
    _ = pc;
    _ = pv;

    // Shinigami runs forever, reaping zombie souls
    while (true) {
        _ = kata.reap();
        kata.yield();
    }

    return 0;
}
