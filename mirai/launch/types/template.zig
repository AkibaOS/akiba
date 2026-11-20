//! Sealed Frame Retention Owned By A Provisioner

const Node = @import("common").datatypes.tree.types.node.Node;
const Reference = @import("mirai").user.types.backing.Reference;

pub const Template = struct {
    ID: u64,
    OwnerID: u64,
    Frame: Reference,
    Index: Node = .{},
    Next: ?*Template = null,
};
