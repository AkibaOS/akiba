//! Crimson Global State

const types = @import("../types/types.zig");

const ExceptionType = types.kind.ExceptionType;

var initialized: bool = false;
var exception_count: u64 = 0;
var last_exception_type: ExceptionType = .Collapse;
var last_exception_address: u64 = 0;

pub fn initialize() void {
    exception_count = 0;
    last_exception_type = .Collapse;
    last_exception_address = 0;
    initialized = true;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn recordException(exception_type: ExceptionType, address: u64) void {
    exception_count += 1;
    last_exception_type = exception_type;
    last_exception_address = address;
}

pub fn getExceptionCount() u64 {
    return exception_count;
}

pub fn getLastExceptionType() ExceptionType {
    return last_exception_type;
}

pub fn getLastExceptionAddress() u64 {
    return last_exception_address;
}

pub fn resetStatistics() void {
    exception_count = 0;
}
