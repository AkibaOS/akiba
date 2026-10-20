//! Received Exceptions

const types = @import("mirai").crimson.types;

const Context = types.context.Context;
const ExceptionType = types.kind.ExceptionType;
const Identity = types.identity.Identity;

pub const ReceivedExceptionDefault = struct {
    PortId: u64,
    ThreadId: u64,
    KataId: u64,
    ExceptionType: ExceptionType,
    Code: u64,
    Subcode: u64,
};

pub const ReceivedExceptionState = struct {
    Base: ReceivedExceptionDefault,
    Context: *Context,
};

pub const ReceivedExceptionStateIdentity = struct {
    Base: ReceivedExceptionDefault,
    Context: *Context,
    Identity: *Identity,
    ThreadPort: u64,
    KataPort: u64,
};
