//! Page Table Entry Type

const address = @import("utils").address;

pub const Entry = packed struct {
    Present: bool = false,
    Writable: bool = false,
    UserAccessible: bool = false,
    WriteThrough: bool = false,
    CacheDisabled: bool = false,
    Accessed: bool = false,
    Dirty: bool = false,
    HugePage: bool = false,
    Global: bool = false,
    AvailableLow: u3 = 0,
    PhysicalAddress: u40 = 0,
    AvailableHigh: u11 = 0,
    NoExecute: bool = false,

    pub fn isPresent(self: Entry) bool {
        return self.Present;
    }

    pub fn isWritable(self: Entry) bool {
        return self.Writable;
    }

    pub fn isUser(self: Entry) bool {
        return self.UserAccessible;
    }

    pub fn isHuge(self: Entry) bool {
        return self.HugePage;
    }

    pub fn getPhysicalAddress(self: Entry) u64 {
        return address.translate.pageToAddress(self.PhysicalAddress);
    }

    pub fn setPhysicalAddress(self: *Entry, physical_address: u64) void {
        self.PhysicalAddress = @truncate(address.translate.addressToPage(physical_address));
    }

    pub fn clear(self: *Entry) void {
        self.* = Entry{};
    }

    pub fn fromRaw(raw: u64) Entry {
        return @bitCast(raw);
    }

    pub fn toRaw(self: Entry) u64 {
        return @bitCast(self);
    }
};
