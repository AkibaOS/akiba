//! Port Lookup (Thread → Kata → Host Chain)

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const thread = @import("thread.zig");
const kata = @import("kata.zig");
const host = @import("host.zig");

const Port = types.Port;
const Exception = types.Exception;
const ExceptionType = constants.ExceptionType;

pub const LookupResult = struct {
    port: *const Port,
    found: bool,
};

pub fn find_port(exception: *const Exception) LookupResult {
    return find_port_for(exception.thread_id, exception.kata_id, exception.exception_type);
}

pub fn find_port_for(thread_id: u64, kata_id: u64, exception_type: ExceptionType) LookupResult {
    if (thread.has_port(thread_id, exception_type)) {
        return LookupResult{
            .port = thread.get_port(thread_id, exception_type),
            .found = true,
        };
    }

    if (kata.has_port(kata_id, exception_type)) {
        return LookupResult{
            .port = kata.get_port(kata_id, exception_type),
            .found = true,
        };
    }

    if (host.has_port(exception_type)) {
        return LookupResult{
            .port = host.get_port(exception_type),
            .found = true,
        };
    }

    return LookupResult{
        .port = undefined,
        .found = false,
    };
}

pub fn has_any_port(thread_id: u64, kata_id: u64, exception_type: ExceptionType) bool {
    return thread.has_port(thread_id, exception_type) or
        kata.has_port(kata_id, exception_type) or
        host.has_port(exception_type);
}
