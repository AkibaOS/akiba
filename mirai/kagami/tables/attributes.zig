//! Runtime Leaf Entry Attributes

const constants = @import("mirai").kagami.constants.protection;
const types = @import("mirai").kagami.types;

pub fn apply(entry: *types.entry.Entry, protection: u8) void {
    entry.Writable = (protection & constants.WRITE) != 0;
    entry.UserAccessible = (protection & constants.USER) != 0;
    entry.WriteThrough = (protection & constants.NOCACHE) != 0;
    entry.CacheDisabled = entry.WriteThrough;
    entry.HugePage = false;
    entry.Global = !entry.UserAccessible;
    entry.NoExecute = (protection & constants.EXECUTE) == 0;
    entry.setWired((protection & constants.WIRED) != 0);
}

pub fn make(physical_address: u64, protection: u8) types.entry.Entry {
    var entry = types.entry.Entry{ .Present = true };
    entry.setPhysicalAddress(physical_address);
    apply(&entry, protection);
    return entry;
}
