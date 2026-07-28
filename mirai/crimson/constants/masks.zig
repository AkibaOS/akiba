//! Exception Mask Constants

const types = @import("mirai").crimson.types;

const ExceptionType = types.kind.ExceptionType;
const Mask = types.mask.Mask;

pub const MASK_NONE: Mask = 0;
pub const MASK_BREACH: Mask = 1 << @intFromEnum(ExceptionType.Breach);
pub const MASK_FORBIDDEN: Mask = 1 << @intFromEnum(ExceptionType.Forbidden);
pub const MASK_OVERFLOW: Mask = 1 << @intFromEnum(ExceptionType.Overflow);
pub const MASK_SHATTER: Mask = 1 << @intFromEnum(ExceptionType.Shatter);
pub const MASK_MISSING: Mask = 1 << @intFromEnum(ExceptionType.Missing);
pub const MASK_CRITICAL: Mask = 1 << @intFromEnum(ExceptionType.Critical);
pub const MASK_SOFTWARE: Mask = 1 << @intFromEnum(ExceptionType.Software);
pub const MASK_RESOURCE: Mask = 1 << @intFromEnum(ExceptionType.Resource);
pub const MASK_GUARD: Mask = 1 << @intFromEnum(ExceptionType.Guard);
pub const MASK_COLLAPSE: Mask = 1 << @intFromEnum(ExceptionType.Collapse);

pub const MASK_ALL: Mask = 0x3FF;
pub const MASK_RECOVERABLE: Mask = MASK_BREACH | MASK_FORBIDDEN | MASK_OVERFLOW | MASK_SHATTER | MASK_MISSING | MASK_SOFTWARE | MASK_RESOURCE | MASK_GUARD;
pub const MASK_FATAL: Mask = MASK_CRITICAL | MASK_COLLAPSE;
