//! Hikari Page Table Entry Type

const common = @import("common");

const indices = common.constants.paging.indices;

pub const PageTableEntry = packed struct(u64) {
    Present: bool,
    Writable: bool,
    User: bool,
    WriteThrough: bool,
    CacheDisable: bool,
    Accessed: bool,
    Dirty: bool,
    HugePage: bool,
    Global: bool,
    AvailableLow: u3,
    AddressBits: u40,
    AvailableHigh: u11,
    NoExecute: bool,

    pub fn empty() PageTableEntry {
        return @bitCast(@as(u64, 0));
    }

    pub fn fromAddress(address: u64, flags: u64) PageTableEntry {
        const entry: u64 = (address & indices.ADDRESS_MASK) | flags;
        return @bitCast(entry);
    }

    pub fn getAddress(self: PageTableEntry) u64 {
        const raw: u64 = @bitCast(self);
        return raw & indices.ADDRESS_MASK;
    }

    pub fn isPresent(self: PageTableEntry) bool {
        return self.Present;
    }

    pub fn isHuge(self: PageTableEntry) bool {
        return self.HugePage;
    }

    pub fn toRaw(self: PageTableEntry) u64 {
        return @bitCast(self);
    }
};
