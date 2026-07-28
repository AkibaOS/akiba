//! Text Rendering Errors

const font = @import("shared").font;
const raster = @import("shared").raster;

pub const TextError = font.errors.font.FontError || raster.errors.raster.RasterError;
