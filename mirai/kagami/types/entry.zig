//! Page Table Entry Type

const common = @import("root").common;
const paging_flags = common.constants.paging.flags;

pub const Entry = packed struct {
    present: bool = false,
    writable: bool = false,
    user_accessible: bool = false,
    write_through: bool = false,
    cache_disabled: bool = false,
    accessed: bool = false,
    dirty: bool = false,
    huge_page: bool = false,
    global: bool = false,
    available_low: u3 = 0,
    physical_address: u40 = 0,
    available_high: u11 = 0,
    no_execute: bool = false,

    pub fn is_present(self: Entry) bool {
        return self.present;
    }

    pub fn is_writable(self: Entry) bool {
        return self.writable;
    }

    pub fn is_user(self: Entry) bool {
        return self.user_accessible;
    }

    pub fn is_huge(self: Entry) bool {
        return self.huge_page;
    }

    pub fn get_physical_address(self: Entry) u64 {
        return @as(u64, self.physical_address) << 12;
    }

    pub fn set_physical_address(self: *Entry, address: u64) void {
        self.physical_address = @truncate(address >> 12);
    }

    pub fn clear(self: *Entry) void {
        self.* = Entry{};
    }

    pub fn from_raw(raw: u64) Entry {
        return @bitCast(raw);
    }

    pub fn to_raw(self: Entry) u64 {
        return @bitCast(self);
    }
};
