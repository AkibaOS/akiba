//! Exception Mask Operations

const types = @import("mirai").crimson.types;

const ExceptionType = types.kind.ExceptionType;
const Mask = types.mask.Mask;

pub fn includes(mask: Mask, exception_type: ExceptionType) bool {
    return (mask & fromType(exception_type)) != 0;
}

pub fn add(mask: Mask, exception_type: ExceptionType) Mask {
    return mask | fromType(exception_type);
}

pub fn remove(mask: Mask, exception_type: ExceptionType) Mask {
    return mask & ~fromType(exception_type);
}

pub fn fromType(exception_type: ExceptionType) Mask {
    return @as(Mask, 1) << @intCast(@intFromEnum(exception_type));
}
