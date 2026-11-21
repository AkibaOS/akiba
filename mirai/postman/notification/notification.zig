//! Committed Mailbox Wakeups

const deadline = @import("mirai").sensei.deadline;
const messages = @import("mirai").postman.strings.invariants;
const wait = @import("mirai").sensei.wait;

const Mailbox = @import("mirai").postman.types.mailbox.queues.Mailbox;
const Record = @import("mirai").postman.types.record.delivery.Record;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn receiver(mailbox: *Mailbox) ?*Thread {
    if (mailbox.Receivers.Head) |record| deadline.completed(record);
    return wait.wakeOldest(&mailbox.Receivers) catch @panic(messages.INVALID_WAITERS);
}

pub fn receivers(mailbox: *Mailbox) void {
    var current = mailbox.Receivers.Head;
    while (current) |record| : (current = record.Next) deadline.completed(record);
    if (mailbox.Receivers.Head == null) return;
    _ = wait.wakeAll(&mailbox.Receivers) catch @panic(messages.INVALID_WAITERS);
}

pub fn caller(client: *Record) void {
    var current = client.Callers.Head;
    while (current) |record| : (current = record.Next) deadline.completed(record);
    if (client.Callers.Head == null) return;
    _ = wait.wakeAll(&client.Callers) catch @panic(messages.INVALID_WAITERS);
}
