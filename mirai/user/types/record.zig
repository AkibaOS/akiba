//! Stable Indexed Owned User Page Record

const kagami = @import("mirai").kagami;
const kata = @import("mirai").kata;
const stage = @import("mirai").user.types.stage;
const tree = @import("common").datatypes.tree;

const Kagami = kagami.types.kagami.Kagami;
const Kata = kata.types.kata.Kata;
const Node = tree.types.node.Node;
const Stage = stage.Stage;

pub const Record = struct {
    Owner: *Kata,
    Root: *Kagami,
    VA: u64,
    PA: u64,
    Stage: Stage = .Loading,
    VirtualIndex: Node = .{},
    PhysicalIndex: Node = .{},
    Previous: ?*Record = null,
    Next: ?*Record = null,
};
