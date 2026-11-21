//! Validate And Copy Initial AHCI Driver Invocations

const std = @import("std");

const authority = @import("mirai").device.ahci.authority;
const bootstrap = @import("mirai").bootstrap.driver.handoff;
const copy = @import("mirai").user.copy.transfer;
const wire = @import("shared").ahci.constants.command.dma;

const BootOperation = @import("shared").pulse.types.boot.driver.Operation;
const Command = @import("shared").ahci.types.command.operation.Operation;
const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Grant = @import("mirai").device.types.ahci.grant.Grant;
const Operation = @import("shared").ahci.types.device.invocation.Operation;
const Status = @import("shared").persona.types.invocation.Status;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn start(caller: *Thread, frame: *Frame) void {
    const value = startup(caller, frame) catch |failure| return respond(frame, status(failure), 0);
    respond(frame, .Success, value);
}

pub fn device(caller: *Thread, frame: *Frame) void {
    perform(caller, frame) catch |failure| return respond(frame, status(failure), 0);
    respond(frame, .Success, 0);
}

fn startup(caller: *Thread, frame: *const Frame) !u64 {
    const operation = std.enums.fromInt(BootOperation, frame.RDI) orelse return error.InvalidArgument;
    if (frame.RDX != 0 or frame.R10 != 0) return error.InvalidArgument;
    return switch (operation) {
        .StartAhci => if (frame.RSI == 0) bootstrap.startAhci(caller) else error.InvalidArgument,
        .ConfirmAhci => confirmed: {
            try bootstrap.confirmAhci(caller, frame.RSI);
            break :confirmed 0;
        },
    };
}

fn perform(caller: *Thread, frame: *const Frame) !void {
    const grant = try authority.authorize(caller);
    const operation = std.enums.fromInt(Operation, frame.RDI) orelse return error.InvalidArgument;
    if (frame.R10 != 0 or (operation != .Read and frame.RDX != 0) or (operation == .Confirm and frame.RSI != 0)) return error.InvalidArgument;
    switch (operation) {
        .Describe => {
            const description = authority.describe(grant);
            try copy.write(caller.Owner, frame.RSI, std.mem.asBytes(&description));
        },
        .Identify => try transfer(caller, grant, .Identify, frame.RSI),
        .Read => try transfer(caller, grant, .{ .Read = frame.RSI }, frame.RDX),
        .Confirm => try authority.confirmDisk(grant),
    }
}

fn transfer(caller: *Thread, grant: *const Grant, operation: Command, destination: u64) !void {
    var output: [wire.SECTOR_BYTES]u8 = undefined;
    if (!copy.validate(caller.Owner, destination, output.len, true)) return error.InvalidAddress;
    try authority.transfer(grant, operation, &output);
    try copy.write(caller.Owner, destination, &output);
}

fn respond(frame: *Frame, result: Status, value: u64) void {
    frame.RAX = @intFromEnum(result);
    frame.RDX = value;
}

fn status(failure: anyerror) Status {
    return switch (failure) {
        error.InvalidCaller, error.InvalidThread, error.UnsafeContext => .InvalidCaller,
        error.InvalidArgument => .InvalidArgument,
        error.InvalidAddress, error.InvalidUserRange, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap, error.SealedPage, error.PermissionDenied => .InvalidAddress,
        error.OutOfMemory => .NoResources,
        else => .InvalidState,
    };
}
