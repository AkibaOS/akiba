//! Integer Math Utilities

pub fn divideCeil(numerator: anytype, denominator: @TypeOf(numerator)) @TypeOf(numerator) {
    if (numerator == 0) return 0;
    return (numerator - 1) / denominator + 1;
}

pub fn alignUp(value: anytype, alignment: @TypeOf(value)) @TypeOf(value) {
    return (value + alignment - 1) & ~(alignment - 1);
}

pub fn alignDown(value: anytype, alignment: @TypeOf(value)) @TypeOf(value) {
    return value & ~(alignment - 1);
}

pub fn squareRoot(value: u64) u32 {
    if (value == 0) {
        return 0;
    }

    var remainder = value;
    var result: u64 = 0;
    var bit: u64 = @as(u64, 1) << 62;

    while (bit > remainder) {
        bit >>= 2;
    }

    while (bit != 0) {
        if (remainder >= result + bit) {
            remainder -= result + bit;
            result = (result >> 1) + bit;
        } else {
            result >>= 1;
        }
        bit >>= 2;
    }

    return @intCast(result);
}
