//! Boot ACPI Info

pub const ACPIInfo = extern struct {
    RSDPAddress: u64,
    RSDPVersion: u32,
    Reserved: u32,
};
