//! Bounded One Way Letter Delivery

const fifo = @import("mirai").postman.fifo;
const guard = @import("asm").interrupts.guard;
const inbox = @import("mirai").postman.inbox;
const notification = @import("mirai").postman.notification;
const storage = @import("mirai").postman.storage;
const validate = @import("mirai").postman.validate;

const PostError = @import("mirai").postman.errors.transport.PostError;
const Thread = @import("mirai").thread.types.thread.Thread;

pub fn send(sender: *Thread, destination_id: u64, letter_type: u64, payload: []const u8) PostError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.current(sender);
    try validate.payload(payload);
    const destination = try inbox.destination(destination_id);
    const source = try inbox.get(sender.Owner);
    const envelope = try storage.reserve(source, destination, .OneWay, letter_type, payload);
    fifo.append(destination, envelope);
    _ = notification.receiver(destination);
}
