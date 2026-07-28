//! Exception Mask Operations

const types = @import("mirai").crimson.types;

const ExceptionType = types.kind.ExceptionType;
const Mask = types.mask.Mask;

pub fn includes(mask: Mask, exception_type: ExceptionType) bool {
    const bit: Mask = @as(Mask, 1) << @intFromEnum(exception_type);
    return (mask & bit) != 0;
}

pub fn add(mask: Mask, exception_type: ExceptionType) Mask {
    const bit: Mask = @as(Mask, 1) << @intFromEnum(exception_type);
    return mask | bit;
}

pub fn remove(mask: Mask, exception_type: ExceptionType) Mask {
    const bit: Mask = @as(Mask, 1) << @intFromEnum(exception_type);
    return mask & ~bit;
}

pub fn fromType(exception_type: ExceptionType) Mask {
    return @as(Mask, 1) << @intFromEnum(exception_type);
}
