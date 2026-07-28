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
