//! Validate And Publish One Completed Provisioning Draft

const bootstrap = @import("mirai").bootstrap;
const messages = @import("mirai").launch.strings.transaction;
const pages = @import("mirai").launch.draft.pages;
const templates = @import("mirai").launch.templates;
const thread = @import("mirai").thread;

const Transaction = @import("mirai").launch.types.transaction.Transaction;

pub fn start(draft: *Transaction, entry: u64, stack_base: u64, stack_length: u64, startup_address: u64) !u64 {
    const owner = try pages.child(draft);
    if (draft.LoadingPages != 0) return error.InvalidState;
    try bootstrap.image.startup.validate(owner, startup_address);
    const initial = try thread.user.create(owner, entry, stack_base, stack_length, startup_address);
    errdefer thread.destroy.destroy(initial) catch @panic(messages.ROLLBACK_THREAD);
    const identifier = try bootstrap.image.start.start(.{
        .ID = owner.ID,
        .Owner = owner,
        .Thread = initial,
        .ThreadGeneration = thread.state.generation(initial).?,
    });
    templates.commit(draft);
    draft.Child = null;
    return identifier;
}
