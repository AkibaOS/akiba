//! Dispatch Privileged Launch Provisioning For The Active Call

const std = @import("std");

const abi = @import("shared").persona.types.invocation;
const copy = @import("mirai").user.copy.transfer;
const letters = @import("shared").launch.constants.service.postman;
const messages = @import("mirai").launch.strings.transaction;
const pages = @import("mirai").launch.draft.pages;
const publish = @import("mirai").launch.draft.publish;
const reply = @import("mirai").postman.reply;
const request = @import("mirai").launch.request.lease;
const templates = @import("mirai").launch.templates;
const types = @import("shared").launch.types.provision;

const Frame = @import("mirai").interrupts.types.frame.InterruptFrame;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn dispatch(current: *Thread, frame: *Frame) void {
    if (perform(current, frame)) |result| {
        frame.RAX = @intFromEnum(abi.Status.Success);
        frame.RDX = result;
    } else |failure| {
        frame.RAX = @intFromEnum(status(failure));
        frame.RDX = 0;
    }
}

fn perform(current: *Thread, frame: *const Frame) !u64 {
    const envelope = try request.active(current, frame.RDI);
    const operation = std.enums.fromInt(types.Operation, frame.RSI) orelse return error.InvalidArgument;
    switch (operation) {
        .Begin => {
            try request.begin(envelope, current.Owner);
            return 0;
        },
        .Abort => {
            try request.abort(envelope);
            return 0;
        },
        .Forget => {
            try templates.forget(current.Owner, frame.RDX);
            return 0;
        },
        else => {},
    }
    const draft = request.transaction(envelope) orelse return error.InvalidState;
    if (draft.Server != current.Owner) return error.InvalidCaller;
    switch (operation) {
        .Allocate => try pages.allocate(draft, frame.RDX),
        .Load => {
            const fields = try input(types.Load, current, frame.RDX);
            try pages.copy(draft, current.Owner, fields.Destination, fields.Source, fields.Length);
        },
        .Seal => {
            const protection = std.enums.fromInt(types.Protection, frame.R10) orelse return error.InvalidArgument;
            try pages.seal(draft, frame.RDX, switch (protection) {
                .ReadOnly => .ReadOnly,
                .ReadWrite => .ReadWrite,
                .ReadExecute => .ReadExecute,
            });
        },
        .Start => {
            const fields = try input(types.Start, current, frame.RDX);
            const attached = draft.Attached;
            const child = try publish.start(draft, fields.Entry, fields.StackBase, fields.StackLength, fields.Startup);
            if (attached) {
                var payload: [@sizeOf(u64)]u8 = undefined;
                std.mem.writeInt(u64, &payload, child, .little);
                reply.send(current, frame.RDI, letters.STARTED, &payload) catch @panic(messages.COMMITTED_REPLY);
            } else envelope.PublishedChild = child;
            return child;
        },
        .Retain => return templates.retain(draft, frame.RDX),
        .Attach => {
            const fields = try input(types.Attach, current, frame.RDX);
            try templates.attach(draft, fields.Handle, fields.Address);
        },
        .AttachVerified => {
            const fields = try input(types.AttachVerified, current, frame.RDX);
            const protection = std.enums.fromInt(types.Protection, frame.R10) orelse return error.InvalidArgument;
            if (protection == .ReadWrite) return error.InvalidArgument;
            try templates.attachVerified(draft, fields.Handle, fields.Address, fields.Source, protection == .ReadExecute);
        },
        .Begin, .Abort, .Forget => unreachable,
    }
    return 0;
}

fn input(comptime T: type, current: *const Thread, address: u64) !T {
    var fields: T = undefined;
    try copy.read(current.Owner, std.mem.asBytes(&fields), address);
    return fields;
}

fn status(failure: anyerror) abi.Status {
    return switch (failure) {
        error.InvalidCaller, error.InvalidThread => .InvalidCaller,
        error.InvalidArgument, error.InvalidStartup => .InvalidArgument,
        error.InvalidUserRange, error.InvalidAddress, error.AddressNotAligned, error.NotOwned, error.InvalidOwnedMapping, error.InvalidPhysmap => .InvalidAddress,
        error.CopyTooLarge => .TooLarge,
        error.InvalidReply => .InvalidReply,
        error.InvalidTarget, error.InvalidTemplateHandle => .InvalidTarget,
        error.PeerGone => .PeerGone,
        error.Busy => .Busy,
        error.OutOfMemory, error.NoResources, error.CapacityReached, error.PageTableAllocationFailed => .NoResources,
        error.NotInitialized => .NotInitialized,
        else => .InvalidState,
    };
}
