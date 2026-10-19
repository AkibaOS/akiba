//! Owner Mailbox Closure

const guard = @import("asm").interrupts.guard;
const inbox = @import("mirai").postman.inbox;
const kata = @import("mirai").kata;
const lifetime = @import("mirai").postman.lifetime;
const thread = @import("mirai").thread;
const validate = @import("mirai").postman.validate;

const Kata = kata.types.kata.Kata;
const PostError = @import("mirai").postman.errors.transport.PostError;

pub fn close(owner: *Kata) PostError!void {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    try validate.initialized();
    if (!kata.state.owns(owner) or owner.Permanent) return PostError.InvalidPeer;
    const current = thread.state.getCurrent() orelse return PostError.InvalidThread;
    try validate.current(current);
    if (current.Owner != owner) return PostError.InvalidPeer;
    lifetime.close(try inbox.get(owner));
}
