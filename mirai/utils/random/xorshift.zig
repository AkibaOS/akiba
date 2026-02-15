//! Xorshift64 random number generation

var state: u64 = 0x853C49E6748FEA9B;

pub fn set_seed(s: u64) void {
    state = if (s == 0) 0x853C49E6748FEA9B else s;
}

pub fn next_u64() u64 {
    state ^= state << 13;
    state ^= state >> 7;
    state ^= state << 17;
    return state;
}

pub fn next_u32() u32 {
    return @truncate(next_u64());
}

pub fn byte() u8 {
    return @truncate(next_u64());
}

pub fn range(min: u64, max: u64) u64 {
    return min + (next_u64() % (max - min + 1));
}
