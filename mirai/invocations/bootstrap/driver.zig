//! Validate Initial Driver Start And Confirmation Requests

const std = @import("std");

const afs = @import("mirai").bootstrap.driver.afs;
const ahci = @import("mirai").bootstrap.driver.handoff;
const binding = @import("mirai").device.binding;
const storage = @import("mirai").bootstrap.storage.handoff;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Operation = @import("shared").pulse.types.boot.driver.Operation;
const Role = @import("shared").launch.types.device.Role;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(caller: *Thread, frame: *Frame) void {
    const value = perform(caller, frame) catch |failure| {
        frame.RAX = @intFromEnum(switch (failure) {
            error.InvalidCaller, error.InvalidThread, error.UnsafeContext => Status.InvalidCaller,
            error.InvalidArgument => Status.InvalidArgument,
            error.OutOfMemory => Status.NoResources,
            else => Status.InvalidState,
        });
        frame.RDX = 0;
        return;
    };
    frame.RAX = @intFromEnum(Status.Success);
    frame.RDX = value;
}

fn perform(caller: *Thread, frame: *const Frame) !u64 {
    const operation = std.enums.fromInt(Operation, frame.RDI) orelse return error.InvalidArgument;
    if (frame.R10 != 0 or frame.RDX != 0) return error.InvalidArgument;
    return switch (operation) {
        .StartAhci => if (frame.RSI == 0) ahci.startAhci(caller) else error.InvalidArgument,
        .ConfirmAhci => confirmed: {
            try ahci.confirmAhci(caller, frame.RSI);
            break :confirmed 0;
        },
        .StartAfs => afs.start(caller, frame.RSI),
        .ConfirmAfs => confirmed: {
            try afs.confirm(caller, frame.RSI);
            break :confirmed 0;
        },
        .FindDevice => found: {
            if (storage.forPulse(caller.Owner) == null) return error.InvalidCaller;
            const role = std.enums.fromInt(Role, frame.RSI) orelse return error.InvalidArgument;
            break :found binding.find(role) orelse return error.InvalidTarget;
        },
    };
}
