//! Exception Message

const types = @import("mirai").crimson.types;

const Context = types.context.Context;
const Identity = types.identity.Identity;

pub const ExceptionMessage = struct {
    ExceptionType: u8,
    Code: u64,
    Subcode: u64,
    ThreadId: u64,
    KataId: u64,
    Context: ?*Context,
    Identity: ?*Identity,
};
