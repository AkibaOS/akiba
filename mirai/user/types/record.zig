//! Stable Indexed Owned User Page Record

const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const Backing = @import("mirai").user.types.backing.Backing;
const tree = @import("common").datatypes.tree;

const Kagami = kagami.types.kagami.Kagami;
const Kata = kata.types.kata.Kata;
const Node = tree.types.node.Node;

pub const Record = struct {
    Owner: *Kata,
    Root: *Kagami,
    VA: u64,
    Backing: *Backing,
    VirtualIndex: Node = .{},
    Previous: ?*Record = null,
    Next: ?*Record = null,
};
