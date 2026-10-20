//! Parsed Reply Action

const types = @import("mirai").crimson.types;

const Action = types.behavior.Action;
const Context = types.context.Context;

pub const ParsedAction = struct {
    Action: Action,
    ModifyState: bool,
    NewContext: ?*Context,
    Valid: bool,
};
