//! Crimson - Akiba Exception Handling System

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const context = @import("context/context.zig");
pub const classify = @import("classify/classify.zig");
pub const handlers = @import("handlers/handlers.zig");
pub const ports = @import("ports/ports.zig");
pub const raise = @import("raise/raise.zig");
pub const propagate = @import("propagate/propagate.zig");
pub const receive = @import("receive/receive.zig");
pub const corpse = @import("corpse/corpse.zig");
pub const panic = @import("panic/panic.zig");
pub const render = @import("render/render.zig");
pub const recover = @import("recover/recover.zig");
pub const state = @import("state.zig");

pub const ExceptionType = constants.ExceptionType;
pub const Behavior = constants.Behavior;
pub const Action = constants.Action;
pub const Flavor = constants.Flavor;

pub const Exception = types.Exception;
pub const Context = types.Context;
pub const Frame = types.Frame;
pub const Port = types.Port;
pub const Corpse = types.Corpse;
pub const Identity = types.Identity;

pub const collapse = panic.collapse;
pub const dispatch = handlers.dispatch;
pub const triage = propagate.triage;

pub fn initialize() void {
    state.initialize();
}

pub fn handle_exception(vector: u8, frame: *types.Frame, regs: *types.Context) Action {
    var exception = handlers.create_exception(vector, frame, regs);
    state.record_exception(exception.exception_type, exception.address);
    return propagate.triage(&exception);
}
