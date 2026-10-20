//! Propagated Exception Reply

const Action = @import("mirai").crimson.types.behavior.Action;

pub const Reply = struct {
    Action: Action,
    NewState: bool,
    Valid: bool,
};
