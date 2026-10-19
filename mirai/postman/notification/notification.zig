//! Committed Mailbox Wakeups

const messages = @import("mirai").postman.strings.invariants;
const wait = @import("mirai").sensei.wait;

const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const Record = @import("mirai").postman.types.record.Record;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn receiver(mailbox: *Mailbox) ?*Thread {
    return wait.wakeOldest(&mailbox.Receivers) catch @panic(messages.INVALID_WAITERS);
}

pub fn receivers(mailbox: *Mailbox) void {
    if (mailbox.Receivers.Head == null) return;
    _ = wait.wakeAll(&mailbox.Receivers) catch @panic(messages.INVALID_WAITERS);
}

pub fn caller(client: *Record) void {
    if (client.Callers.Head == null) return;
    _ = wait.wakeAll(&client.Callers) catch @panic(messages.INVALID_WAITERS);
}
