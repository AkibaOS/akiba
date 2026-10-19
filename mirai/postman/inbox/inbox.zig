//! Lazy Kata Mailbox Records

const kata = @import("mirai").kata;
const state = @import("mirai").postman.state;

const Kata = kata.types.kata.Kata;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const PostError = @import("mirai").postman.errors.transport.PostError;

pub fn find(owner: *const Kata) ?*Mailbox {
    for (&state.getState().Mailboxes) |*mailbox| {
        if (mailbox.Owner == owner and mailbox.ID == owner.ID) return mailbox;
    }
    return null;
}

pub fn get(owner: *Kata) PostError!*Mailbox {
    if (!kata.state.owns(owner) or owner.Permanent) return PostError.InvalidPeer;
    if (find(owner)) |mailbox| return mailbox;
    for (&state.getState().Mailboxes) |*mailbox| {
        if (mailbox.Owner != null) continue;
        mailbox.* = .{ .Owner = owner, .ID = owner.ID };
        return mailbox;
    }
    return PostError.NoResources;
}

pub fn destination(identifier: u64) PostError!*Mailbox {
    const owner = kata.state.findByID(identifier) orelse return PostError.InvalidPeer;
    return get(owner);
}
