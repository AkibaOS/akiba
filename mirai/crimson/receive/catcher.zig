//! Catch Exception (Receive Side)

const types = @import("mirai").crimson.types;

const Context = types.context.Context;
const ExceptionType = types.kind.ExceptionType;
const Identity = types.identity.Identity;

const ReceivedExceptionDefault = types.receive.catcher.ReceivedExceptionDefault;
const ReceivedExceptionState = types.receive.catcher.ReceivedExceptionState;
const ReceivedExceptionStateIdentity = types.receive.catcher.ReceivedExceptionStateIdentity;

pub fn catchExceptionRaise(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64) ReceivedExceptionDefault {
    return ReceivedExceptionDefault{
        .PortId = port_id,
        .ThreadId = thread_id,
        .KataId = kata_id,
        .ExceptionType = exception_type,
        .Code = code,
        .Subcode = subcode,
    };
}

pub fn catchExceptionRaiseState(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64, context: *Context) ReceivedExceptionState {
    return ReceivedExceptionState{
        .Base = catchExceptionRaise(port_id, thread_id, kata_id, exception_type, code, subcode),
        .Context = context,
    };
}

pub fn catchExceptionRaiseStateIdentity(port_id: u64, thread_id: u64, kata_id: u64, exception_type: ExceptionType, code: u64, subcode: u64, context: *Context, identity: *Identity, thread_port: u64, kata_port: u64) ReceivedExceptionStateIdentity {
    return ReceivedExceptionStateIdentity{
        .Base = catchExceptionRaise(port_id, thread_id, kata_id, exception_type, code, subcode),
        .Context = context,
        .Identity = identity,
        .ThreadPort = thread_port,
        .KataPort = kata_port,
    };
}
