//! Hikari Graphics Output Locator

const efi = @import("../efi/efi.zig");

pub fn get_graphics_output(boot_services: *efi.services.BootServices) ?*efi.protocols.GraphicsOutputProtocol {
    var gop: ?*anyopaque = null;
    const status = boot_services.locate_protocol(
        &efi.constants.guids.graphics_output_protocol,
        null,
        &gop,
    );
    if (efi.types.is_error(status)) {
        return null;
    }
    return @ptrCast(@alignCast(gop));
}
