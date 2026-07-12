//! Exception Masks

const constants = @import("../constants.zig");

const ExceptionType = constants.ExceptionType;

pub const Mask = u16;

pub const mask_none: Mask = 0;
pub const mask_breach: Mask = 1 << @intFromEnum(ExceptionType.breach);
pub const mask_forbidden: Mask = 1 << @intFromEnum(ExceptionType.forbidden);
pub const mask_overflow: Mask = 1 << @intFromEnum(ExceptionType.overflow);
pub const mask_shatter: Mask = 1 << @intFromEnum(ExceptionType.shatter);
pub const mask_missing: Mask = 1 << @intFromEnum(ExceptionType.missing);
pub const mask_critical: Mask = 1 << @intFromEnum(ExceptionType.critical);
pub const mask_software: Mask = 1 << @intFromEnum(ExceptionType.software);
pub const mask_resource: Mask = 1 << @intFromEnum(ExceptionType.resource);
pub const mask_guard: Mask = 1 << @intFromEnum(ExceptionType.guard);
pub const mask_collapse: Mask = 1 << @intFromEnum(ExceptionType.collapse);

pub const mask_all: Mask = 0x3FF;
pub const mask_recoverable: Mask = mask_breach | mask_forbidden | mask_overflow | mask_shatter | mask_missing | mask_software | mask_resource | mask_guard;
pub const mask_fatal: Mask = mask_critical | mask_collapse;

pub fn includes(mask: Mask, exception_type: ExceptionType) bool {
    const bit: Mask = 1 << @intFromEnum(exception_type);
    return (mask & bit) != 0;
}

pub fn add(mask: Mask, exception_type: ExceptionType) Mask {
    const bit: Mask = 1 << @intFromEnum(exception_type);
    return mask | bit;
}

pub fn remove(mask: Mask, exception_type: ExceptionType) Mask {
    const bit: Mask = 1 << @intFromEnum(exception_type);
    return mask & ~bit;
}

pub fn from_type(exception_type: ExceptionType) Mask {
    return @as(Mask, 1) << @intFromEnum(exception_type);
}
