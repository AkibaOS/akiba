//! Hikari EFI Loaded Image Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;

const convention = constants.convention.CALLING_CONVENTION;

pub const LoadedImageProtocol = extern struct {
    Revision: u32,
    ParentHandle: types.base.Handle,
    SystemTable: *anyopaque,
    DeviceHandle: types.base.Handle,
    UnitLocation: *anyopaque,
    Reserved: *anyopaque,
    LoadOptionsSize: u32,
    LoadOptions: *anyopaque,
    ImageBase: [*]u8,
    ImageSize: u64,
    ImageCodeType: types.memory.MemoryType,
    ImageDataType: types.memory.MemoryType,
    Unload: *const fn (image_handle: types.base.Handle) callconv(convention) types.base.Status,
};
