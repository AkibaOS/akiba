//! Copied Loader Retirement Geometry

const inventory = @import("shared").boot.types.retirement;
const memory = @import("shared").boot.types.memory;
const storage = @import("mirai").pmm.types.storage.layout;

pub const RawMap = struct {
    Map: memory.MemoryMapInfo,
    Ordered: bool,
};

pub const Footprint = struct {
    Tables: inventory.Inventory,
    Root: storage.Range,
    Stack: storage.Range,
    Parameters: storage.Range,
    Map: storage.Range,

    pub fn fixed(self: Footprint) [4]storage.Range {
        return .{ self.Root, self.Stack, self.Parameters, self.Map };
    }
};
