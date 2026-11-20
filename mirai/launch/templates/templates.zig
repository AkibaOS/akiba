//! Draft Retention And Committed Provisioner Backing Ownership

const allocator = @import("mirai").memory.allocator.native;
const guard = @import("asm").interrupts.guard;
const messages = @import("mirai").launch.strings.transaction;
const pages = @import("mirai").launch.draft.pages;
const reference = @import("mirai").user.memory.reference;
const state = @import("mirai").kata.state;
const tree = @import("common").datatypes.tree;

const Kata = @import("mirai").kata.types.kata.Kata;
const Template = @import("mirai").launch.types.template.Template;
const Transaction = @import("mirai").launch.types.transaction.Transaction;
const Tree = tree.types.index.Tree;
const UserError = @import("mirai").user.errors.memory.UserError;

var identities: Tree = .{};
var next_id: u64 = 1;

pub fn retain(draft: *Transaction, address: u64) !u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (next_id == 0) return error.OutOfMemory;
    const child = try pages.child(draft);
    const heap = allocator.get();
    const entry = try heap.create(Template);
    errdefer heap.destroy(entry);
    entry.* = .{ .ID = next_id, .OwnerID = draft.Server.ID, .Frame = try reference.retain(child, address), .Next = draft.Pending };
    draft.Pending = entry;
    next_id +%= 1;
    return entry.ID;
}

pub fn attach(draft: *Transaction, handle: u64, address: u64) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const child = try pages.child(draft);
    const entry = find(handle) orelse return error.InvalidTemplateHandle;
    if (entry.OwnerID != draft.Server.ID) return error.InvalidTemplateHandle;
    try reference.map(&entry.Frame, child, address);
}

pub fn commit(draft: *Transaction) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (draft.Pending == null) return;
    const slot = state.data(draft.Server) orelse @panic(messages.TEMPLATE_STATE);
    while (draft.Pending) |entry| {
        draft.Pending = entry.Next;
        if (!tree.insert.insert(&identities, &entry.Index, entry.ID)) @panic(messages.TEMPLATE_STATE);
        entry.Next = slot.Templates;
        slot.Templates = entry;
    }
}

pub fn discard(draft: *Transaction) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    while (draft.Pending) |entry| {
        draft.Pending = entry.Next;
        drop(entry);
    }
}

pub fn validateOwner(owner: *const Kata) UserError!void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = state.data(owner) orelse return UserError.InvalidOwner;
    var current = slot.Templates;
    while (current) |entry| : (current = entry.Next) {
        if (entry.OwnerID != owner.ID or find(entry.ID) != entry) return UserError.InvalidOwnedMapping;
        try reference.validate(&entry.Frame);
    }
}

pub fn releaseOwner(owner: *const Kata) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const slot = state.data(owner) orelse @panic(messages.TEMPLATE_STATE);
    while (slot.Templates) |entry| {
        if (!tree.remove.remove(&identities, &entry.Index)) @panic(messages.TEMPLATE_STATE);
        slot.Templates = entry.Next;
        drop(entry);
    }
}

fn find(handle: u64) ?*Template {
    const node = tree.lookup.find(&identities, handle) orelse return null;
    return @fieldParentPtr(messages.TEMPLATE_INDEX, node);
}

fn drop(entry: *Template) void {
    reference.drop(&entry.Frame) catch @panic(messages.TEMPLATE_STATE);
    allocator.get().destroy(entry);
}
