//! Unpublished Child Ownership Through An Authenticated Call

const std = @import("std");

const allocator = @import("mirai").memory.allocator.native;
const codec = @import("shared").launch.service.request;
const control = @import("asm").cpu.constants.control.registers;
const cpu = @import("asm").cpu.state;
const handoff = @import("mirai").bootstrap.weaver.handoff;
const instances = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const letters = @import("shared").launch.constants.service.postman;
const messages = @import("mirai").launch.strings.transaction;
const postman = @import("mirai").postman;
const schedule = @import("mirai").sensei.registry;
const templates = @import("mirai").launch.templates;

const Envelope = postman.types.envelope.Envelope;
const Kata = kata.types.kata.Kata;
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
    const sender_record = schedule.find(sender) orelse return PostError.PeerGone;
    if (sender_record.TimedOut) {
        postman.storage.revokeLease(envelope);
        return PostError.PeerGone;
    }
    return envelope;
}

pub fn begin(envelope: *Envelope, server: *Kata) !void {
    if (envelope.Lease != null) return PostError.Busy;
    const launcher = envelope.Client.?.Owner.?;
    const selected = try device(envelope, launcher, server);
    const heap = allocator.get();
    const draft = try heap.create(Transaction);
    errdefer heap.destroy(draft);
    const child = try kata.create.createFor(launcher);
    errdefer kata.destroy.destroy(child) catch @panic(messages.ROLLBACK_FAILED);
    if (selected) |identifier| _ = try instances.reserve(identifier, child);
    draft.* = .{ .Child = child, .Server = server, .Attached = selected != null };
    envelope.Lease = .{ .Context = draft, .Revoke = revoke };
}

fn device(envelope: *const Envelope, launcher: *const Kata, server: *const Kata) !?u64 {
    if (envelope.Header.Type != letters.DRIVER) return null;
    if (handoff.assignedTo(launcher.ID) != server.ID) return error.InvalidCaller;
    const request = codec.decodeAttached(envelope.Payload[0..@intCast(envelope.Header.Length)]) orelse return error.InvalidArgument;
    return request.Instance;
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
    templates.discard(draft);
    if (draft.Child) |child| kata.destroy.destroy(child) catch @panic(messages.ROLLBACK_FAILED);
    allocator.get().destroy(draft);
}
