//! Catch Exception (Receive Side)

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const propagate = @import("../propagate/propagate.zig");

const Context = types.Context;
const Identity = types.Identity;
const ExceptionType = constants.ExceptionType;
const Behavior = constants.Behavior;

pub const ReceivedExceptionDefault = struct {
    port_id: u64,
    thread_id: u64,
    kata_id: u64,
    exception_type: ExceptionType,
    code: u64,
    subcode: u64,
};

pub const ReceivedExceptionState = struct {
    base: ReceivedExceptionDefault,
    context: *Context,
};

pub const ReceivedExceptionStateIdentity = struct {
    base: ReceivedExceptionDefault,
    context: *Context,
    identity: *Identity,
    thread_port: u64,
    kata_port: u64,
};

pub fn catch_exception_raise(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64) ReceivedExceptionDefault {
    return ReceivedExceptionDefault{
        .port_id = port_id,
        .thread_id = thread_id,
        .kata_id = kata_id,
        .exception_type = exception_type,
        .code = code,
        .subcode = subcode,
    };
}

pub fn catch_exception_raise_state(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64, context: *Context) ReceivedExceptionState {
    return ReceivedExceptionState{
        .base = catch_exception_raise(port_id, thread_id, kata_id, exception_type, code, subcode),
        .context = context,
    };
}

pub fn catch_exception_raise_state_identity(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64, context: *Context, identity: *Identity, thread_port: u64, kata_port: u64) ReceivedExceptionStateIdentity {
    return ReceivedExceptionStateIdentity{
        .base = catch_exception_raise(port_id, thread_id, kata_id, exception_type, code, subcode),
        .context = context,
        .identity = identity,
        .thread_port = thread_port,
        .kata_port = kata_port,
    };
}
