//! Hikari EFI Graphics Output Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;

const convention = constants.convention.CALLING_CONVENTION;

pub const GraphicsOutputProtocol = extern struct {
    QueryMode: *const fn (
        self: *GraphicsOutputProtocol,
        mode_number: u32,
        size_of_info: *usize,
        info: **types.graphics.GraphicsOutputModeInformation,
    ) callconv(convention) types.base.Status,

    SetMode: *const fn (
        self: *GraphicsOutputProtocol,
        mode_number: u32,
    ) callconv(convention) types.base.Status,

    Blt: *const fn (
        self: *GraphicsOutputProtocol,
        blt_buffer: ?[*]types.graphics.BltPixel,
        blt_operation: types.graphics.BltOperation,
        source_x: usize,
        source_y: usize,
        destination_x: usize,
        destination_y: usize,
        width: usize,
        height: usize,
        delta: usize,
    ) callconv(convention) types.base.Status,

    Mode: *types.graphics.GraphicsOutputProtocolMode,
};
