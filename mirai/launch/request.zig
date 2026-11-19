//! Unpublished Child Ownership Through An Authenticated Call

const std = @import("std");

const allocator = @import("mirai").memory.allocator.native;
const control = @import("asm").cpu.constants.control;
const cpu = @import("asm").cpu.state;
const kata = @import("mirai").kata;
const messages = @import("mirai").launch.strings.transaction;
const postman = @import("mirai").postman;

const Envelope = postman.types.envelope.Envelope;
const PostError = postman.errors.transport.PostError;
const Thread = @import("mirai").thread.types.thread.Thread;
const Transaction = @import("mirai").launch.types.transaction.Transaction;

/// The guard must remain held while the caller uses the delivery and its draft.
pub fn active(server: *Thread, ticket: u64) (PostError || error{InvalidCaller})!*Envelope {
    std.debug.assert(cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE == 0);
    try postman.validate.current(server);
    if (!server.Owner.CanProvision) return error.InvalidCaller;
    const receiver = postman.record.find(server) orelse return PostError.InvalidReply;
    const envelope = receiver.Serving orelse return PostError.InvalidReply;
    if (ticket == 0 or envelope.Ticket != ticket or envelope.Status != .Delivered or envelope.Receiver != receiver)
        return PostError.InvalidReply;
    const client = envelope.Client orelse return PostError.PeerGone;
    const sender = client.Thread orelse return PostError.PeerGone;
    if (!postman.validate.live(sender)) return PostError.PeerGone;
    if (client.Pending != envelope or client.Owner != sender.Owner or envelope.Header.Sender != sender.Owner.ID)
        return PostError.InvalidReply;
    return envelope;
}

pub fn begin(envelope: *Envelope) !void {
    if (envelope.Lease != null) return PostError.Busy;
    const heap = allocator.get();
    const draft = try heap.create(Transaction);
    errdefer heap.destroy(draft);
    draft.* = .{ .Child = try kata.create.createFor(envelope.Client.?.Owner.?) };
    envelope.Lease = .{ .Context = draft, .Revoke = revoke };
}

pub fn abort(envelope: *Envelope) PostError!void {
    const draft = transaction(envelope) orelse return PostError.InvalidState;
    if (draft.Child == null) return PostError.InvalidState;
    postman.storage.revokeLease(envelope);
}

pub fn transaction(envelope: *const Envelope) ?*Transaction {
    const lease = envelope.Lease orelse return null;
    if (lease.Revoke != &revoke) return null;
    return @ptrCast(@alignCast(lease.Context));
}

fn revoke(context: *anyopaque) void {
    const draft: *Transaction = @ptrCast(@alignCast(context));
    if (draft.Child) |child| kata.destroy.destroy(child) catch @panic(messages.ROLLBACK_FAILED);
    allocator.get().destroy(draft);
}
