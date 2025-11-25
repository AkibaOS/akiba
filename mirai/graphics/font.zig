//! PSF font rendering (stubbed until AFS loads fonts)

pub fn init() void {
    // TODO: Load font from /system/fonts/default.psf
}

pub fn get_char_bitmap(_: u8) []const u8 {
    // TODO: Return actual character bitmap from loaded font
    return &[_]u8{};
}
