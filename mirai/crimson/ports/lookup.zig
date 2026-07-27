//! Port Lookup (Thread → Kata → Host Chain)

const host = @import("host.zig");
const kata = @import("kata.zig");
const thread = @import("thread.zig");
const types = @import("../types/types.zig");

const Exception = types.exception.Exception;
const ExceptionType = types.kind.ExceptionType;
const Port = types.port.Port;

pub const LookupResult = struct {
    Port: *const Port,
    Found: bool,
};

pub fn findPort(exception: *const Exception) LookupResult {
    return findPortFor(exception.ThreadId, exception.KataId, exception.ExceptionType);
}

pub fn findPortFor(thread_id: u64, kata_id: u64, exception_type: ExceptionType) LookupResult {
    if (thread.hasPort(thread_id, exception_type)) {
        return LookupResult{
            .Port = thread.getPort(thread_id, exception_type),
            .Found = true,
        };
    }

    if (kata.hasPort(kata_id, exception_type)) {
        return LookupResult{
            .Port = kata.getPort(kata_id, exception_type),
            .Found = true,
        };
    }

    if (host.hasPort(exception_type)) {
        return LookupResult{
            .Port = host.getPort(exception_type),
            .Found = true,
        };
    }

    return LookupResult{
        .Port = undefined,
        .Found = false,
    };
}

pub fn hasAnyPort(thread_id: u64, kata_id: u64, exception_type: ExceptionType) bool {
    return thread.hasPort(thread_id, exception_type) or
        kata.hasPort(kata_id, exception_type) or
        host.hasPort(exception_type);
}
