//! Physical User Frame Backing

const Node = @import("common").datatypes.tree.types.node.Node;
const Stage = @import("mirai").user.types.stage.Stage;

pub const Backing = struct {
    PA: u64,
    References: usize = 1,
    Stage: Stage = .Loading,
    PhysicalIndex: Node = .{},
};

pub const Reference = struct {
    Frame: ?*Backing,
};
