//! Hikari EFI Loaded Image Protocol

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");
const memory = @import("../types/memory.zig");

pub const LoadedImageProtocol = extern struct {
    revision: u32,
    parent_handle: types.Handle,
    system_table: *anyopaque,
    device_handle: types.Handle,
    unit_location: *anyopaque,
    reserved: *anyopaque,
    load_options_size: u32,
    load_options: *anyopaque,
    image_base: [*]u8,
    image_size: u64,
    image_code_type: memory.MemoryType,
    image_data_type: memory.MemoryType,
    unload: *const fn (image_handle: types.Handle) callconv(efi.akiba) types.Status,
};

pub const loaded_image_protocol_revision: u32 = 0x1000;
