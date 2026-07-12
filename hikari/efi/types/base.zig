//! Hikari EFI Base Types

pub const Handle = *opaque {};
pub const Event = *opaque {};
pub const Status = usize;
pub const PhysicalAddress = u64;
pub const VirtualAddress = u64;
pub const Char8 = u8;
pub const Char16 = u16;
pub const Boolean = bool;
pub const LBA = u64;

pub const GUID = extern struct {
    TimeLow: u32,
    TimeMid: u16,
    TimeHighAndVersion: u16,
    ClockSequenceAndNode: [8]u8,

    pub fn equals(self: GUID, other: GUID) bool {
        return self.TimeLow == other.TimeLow and
            self.TimeMid == other.TimeMid and
            self.TimeHighAndVersion == other.TimeHighAndVersion and
            @as(u64, @bitCast(self.ClockSequenceAndNode)) == @as(u64, @bitCast(other.ClockSequenceAndNode));
    }
};

pub fn isError(status: Status) bool {
    return (status >> (@bitSizeOf(Status) - 1)) == 1;
}

pub fn isSuccess(status: Status) bool {
    return status == 0;
}
