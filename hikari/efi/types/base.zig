//! Hikari EFI Base Types

pub const Handle = *opaque {};
pub const Event = *opaque {};
pub const Status = usize;
pub const PhysicalAddress = u64;
pub const VirtualAddress = u64;
pub const Char8 = u8;
pub const Char16 = u16;
pub const Boolean = bool;
pub const Lba = u64;

pub const Guid = extern struct {
    time_low: u32,
    time_mid: u16,
    time_high_and_version: u16,
    clock_sequence_and_node: [8]u8,

    pub fn equals(self: Guid, other: Guid) bool {
        return self.time_low == other.time_low and
            self.time_mid == other.time_mid and
            self.time_high_and_version == other.time_high_and_version and
            @as(u64, @bitCast(self.clock_sequence_and_node)) == @as(u64, @bitCast(other.clock_sequence_and_node));
    }
};

pub fn is_error(status: Status) bool {
    return (status >> 63) == 1;
}

pub fn is_success(status: Status) bool {
    return status == 0;
}
