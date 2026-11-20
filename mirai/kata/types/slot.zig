//! Kata Descriptor And Owner Bound Runtime Storage

const Kata = @import("mirai").kata.types.kata.Kata;
const Mailbox = @import("mirai").postman.types.mailbox.Mailbox;
const Node = @import("common").datatypes.tree.types.node.Node;
const Record = @import("mirai").user.types.record.Record;
const Template = @import("mirai").launch.types.template.Template;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Slot = struct {
    Descriptor: Kata,
    Index: Node = .{},
    Mailbox: Mailbox = .{},
    Pages: ?*Record = null,
    Templates: ?*Template = null,
    Threads: ?*Thread = null,
};
