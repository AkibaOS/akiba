//! Hikari EFI Graphics Output Protocol

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");
const graphics = @import("../types/graphics.zig");

pub const GraphicsOutputProtocol = extern struct {
    query_mode: *const fn (
        self: *GraphicsOutputProtocol,
        mode_number: u32,
        size_of_info: *usize,
        info: **graphics.GraphicsOutputModeInformation,
    ) callconv(efi.akiba) types.Status,

    set_mode: *const fn (
        self: *GraphicsOutputProtocol,
        mode_number: u32,
    ) callconv(efi.akiba) types.Status,

    blt: *const fn (
        self: *GraphicsOutputProtocol,
        blt_buffer: ?[*]graphics.BltPixel,
        blt_operation: graphics.BltOperation,
        source_x: usize,
        source_y: usize,
        destination_x: usize,
        destination_y: usize,
        width: usize,
        height: usize,
        delta: usize,
    ) callconv(efi.akiba) types.Status,

    mode: *graphics.GraphicsOutputProtocolMode,
};
