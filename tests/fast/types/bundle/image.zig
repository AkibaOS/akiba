//! Bounded Scratch For Resolver Tests On A Real AFS Image

const afs = @import("shared").afs;
const size = @import("tests").fast.image.constants.capacity;

pub const Image = struct {
    Catalog: afs.types.reader.Catalog,
    Scratch: [size.CELL_BYTES]u8 = undefined,
    RepeatFirst: bool = false,
};
