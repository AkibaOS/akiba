//! Owner Bound Kata Mailbox Records

const kata = @import("mirai").kata;

const Kata = kata.types.kata.Kata;
const Mailbox = @import("mirai").postman.types.mailbox.queues.Mailbox;
const PostError = @import("mirai").postman.errors.transport.PostError;

pub fn find(owner: *const Kata) ?*Mailbox {
    const slot = kata.state.data(owner) orelse return null;
    const mailbox = &slot.Mailbox;
    return if (mailbox.Owner == owner and mailbox.ID == owner.ID) mailbox else null;
}

pub fn get(owner: *Kata) PostError!*Mailbox {
    if (!kata.state.owns(owner) or owner.Permanent or owner.State == .Born or owner.State == .Dead) return PostError.InvalidPeer;
    if (find(owner)) |mailbox| return mailbox;
    const slot = kata.state.data(owner) orelse return PostError.InvalidPeer;
    if (slot.Mailbox.Owner != null) return PostError.InvalidState;
    slot.Mailbox = .{ .Owner = owner, .ID = owner.ID };
    return &slot.Mailbox;
}

pub fn destination(identifier: u64) PostError!*Mailbox {
    const owner = kata.state.findByID(identifier) orelse return PostError.InvalidPeer;
    return get(owner);
}
