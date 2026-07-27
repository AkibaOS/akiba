//! Raise Guard Exception

const entry = @import("../handlers/entry.zig");
const propagate = @import("../propagate/propagate.zig");
const types = @import("../types/types.zig");

const Action = types.behavior.Action;
const Exception = types.exception.Exception;
const GuardCode = types.codes.GuardCode;

pub fn raisePortGuard(kata_id: u64, thread_id: u64, port_id: u64, operation: u64) Action {
    return raiseGuard(.PortGuard, kata_id, thread_id, port_id, operation);
}

pub fn raiseFileGuard(kata_id: u64, thread_id: u64, file_id: u64, operation: u64) Action {
    return raiseGuard(.FileGuard, kata_id, thread_id, file_id, operation);
}

pub fn raiseMemoryGuard(kata_id: u64, thread_id: u64, address: u64, operation: u64) Action {
    return raiseGuard(.MemoryGuard, kata_id, thread_id, address, operation);
}

fn raiseGuard(guard_code: GuardCode, kata_id: u64, thread_id: u64, code: u64, subcode: u64) Action {
    var context = entry.getExceptionContext();
    context.clear();

    var exception = Exception{
        .ExceptionType = .Guard,
        .Code = code,
        .Subcode = subcode,
        .Vector = 0,
        .Address = code,
        .Context = context,
        .Frame = undefined,
        .KataId = kata_id,
        .ThreadId = thread_id,
        .Recoverable = true,
    };

    _ = guard_code;

    return propagate.triage.triage(&exception);
}
