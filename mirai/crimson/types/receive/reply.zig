//! Exception Reply

const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Context = types.context.Context;

pub const ExceptionReply = struct {
    ReplyPort: u64,
    Action: Action,
    NewContext: ?*Context,
};
