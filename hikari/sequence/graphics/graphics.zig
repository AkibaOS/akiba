//! Hikari Graphics Output Locator

const efi = @import("hikari").efi;

pub fn getGraphicsOutput(boot_services: *efi.types.services.boot.BootServices) ?*efi.types.protocols.graphics.GraphicsOutputProtocol {
    var graphics_output: ?*anyopaque = null;
    const status = boot_services.LocateProtocol(
        &efi.constants.guids.GRAPHICS_OUTPUT_PROTOCOL,
        null,
        &graphics_output,
    );
    if (efi.status.isError(status)) {
        return null;
    }
    return @ptrCast(@alignCast(graphics_output));
}
