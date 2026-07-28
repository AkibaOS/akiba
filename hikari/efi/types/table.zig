//! Hikari EFI Table Types

const base = @import("hikari").efi.types.base;

pub const TableHeader = extern struct {
    Signature: u64,
    Revision: u32,
    HeaderSize: u32,
    CRC32: u32,
    Reserved: u32,
};

pub const ConfigurationTableEntry = extern struct {
    VendorGUID: base.GUID,
    VendorTable: *anyopaque,
};
