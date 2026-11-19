//! Bounded Page Operations On One Unpublished Launch Draft

const kata = @import("mirai").kata;
const user = @import("mirai").user;

const Kata = kata.types.kata.Kata;
const Protection = user.types.protection.Protection;
const Transaction = @import("mirai").launch.types.transaction.Transaction;

pub fn child(draft: *const Transaction) error{InvalidState}!*Kata {
    const owner = draft.Child orelse return error.InvalidState;
    if (!kata.state.owns(owner) or owner.State != .Born or owner.ThreadCount != 0) return error.InvalidState;
    return owner;
}

pub fn allocate(draft: *Transaction, address: u64) !void {
    try user.memory.allocate.allocate(try child(draft), address);
    draft.LoadingPages += 1;
}

pub fn copy(draft: *Transaction, source: *const Kata, destination: u64, address: u64, length: u64) !void {
    const owner = try child(draft);
    if (length == 0) return error.InvalidArgument;
    if (length > user.constants.limits.MAX_COPY_BYTES) return error.CopyTooLarge;
    var storage: [user.constants.limits.MAX_COPY_BYTES]u8 = undefined;
    const bytes = storage[0..@intCast(length)];
    try user.copy.transfer.read(source, bytes, address);
    try user.memory.load.load(owner, destination, bytes);
}

pub fn seal(draft: *Transaction, address: u64, protection: Protection) !void {
    const owner = try child(draft);
    if (draft.LoadingPages == 0) return error.InvalidState;
    try user.memory.finalize.finalize(owner, address, protection);
    draft.LoadingPages -= 1;
}
