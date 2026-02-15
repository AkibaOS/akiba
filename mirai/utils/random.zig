//! Random number generation

var xorshift_state: u64 = 0x853C49E6748FEA9B;

pub fn byte() u8 {
    xorshift_state ^= xorshift_state << 13;
    xorshift_state ^= xorshift_state >> 7;
    xorshift_state ^= xorshift_state << 17;
    return @truncate(xorshift_state);
}

pub fn seed(s: u64) void {
    xorshift_state = if (s == 0) 0x853C49E6748FEA9B else s;
}
