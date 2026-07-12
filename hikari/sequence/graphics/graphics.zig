//! Hikari Graphics Output Locator

const efi = @import("../../efi/efi.zig");

pub fn getGraphicsOutput(boot_services: *efi.services.boot.BootServices) ?*efi.protocols.graphics.GraphicsOutputProtocol {
    var graphics_output: ?*anyopaque = null;
    const status = boot_services.LocateProtocol(
        &efi.constants.guids.GRAPHICS_OUTPUT_PROTOCOL,
        null,
        &graphics_output,
    );
    if (efi.types.base.isError(status)) {
        return null;
    }
    return @ptrCast(@alignCast(graphics_output));
}
