//! Zone Types

const constants = @import("mirai").memory.constants;
const tree = @import("common").datatypes.tree.types;

const limits = constants.zone.limits;
const Node = tree.node.Node;
const Tree = tree.index.Tree;

pub const Zone = struct {
    Name: [constants.zone.limits.NAME_CAPACITY]u8,
    NameLength: u8,
    ElementSize: usize,
    ElementsPerPage: usize,
    PartialPages: ?*ZonePageMeta,
    FullPages: ?*ZonePageMeta,
    AllocationCount: usize,
    FreeCount: usize,
    PageCount: usize,
    PageIndex: Tree = .{},

    pub fn getName(self: *const Zone) []const u8 {
        return self.Name[0..self.NameLength];
    }

    pub fn inUse(self: *const Zone) usize {
        return self.AllocationCount -| self.FreeCount;
    }
};

pub const FreeElement = struct {
    Next: ?*FreeElement,
};

pub const ZonePageMeta = struct {
    Zone: *Zone,
    PageVirtual: u64,
    PagePhysical: u64,
    FreeList: ?*FreeElement,
    InUse: usize,
    Next: ?*ZonePageMeta,
    Previous: ?*ZonePageMeta = null,
    ElementOffset: usize,
    Capacity: usize,
    Index: Node = .{},
    Allocated: [limits.ALLOCATION_BITMAP_BYTES]u8 = [_]u8{0} ** limits.ALLOCATION_BITMAP_BYTES,
};
