//! Crimson Global State

const types = @import("types/types.zig");
const constants = @import("constants/constants.zig");

const Context = types.Context;
const ExceptionType = constants.ExceptionType;

var initialized: bool = false;
var exception_count: u64 = 0;
var last_exception_type: ExceptionType = .collapse;
var last_exception_address: u64 = 0;

pub fn initialize() void {
    exception_count = 0;
    last_exception_type = .collapse;
    last_exception_address = 0;
    initialized = true;
}

pub fn is_initialized() bool {
    return initialized;
}

pub fn record_exception(exception_type: ExceptionType, address: u64) void {
    exception_count += 1;
    last_exception_type = exception_type;
    last_exception_address = address;
}

pub fn get_exception_count() u64 {
    return exception_count;
}

pub fn get_last_exception_type() ExceptionType {
    return last_exception_type;
}

pub fn get_last_exception_address() u64 {
    return last_exception_address;
}

pub fn reset_statistics() void {
    exception_count = 0;
}
