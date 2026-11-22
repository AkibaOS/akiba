//! Typed Bundle Description With Caller Owned Executable Bytes

const Descriptor = @import("shared").bundle.types.manifest.descriptor.Descriptor;

pub const Snapshot = struct {
    Description: Descriptor,
    Bytes: []u8,
};
