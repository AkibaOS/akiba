//! Context Operations

pub const capture = @import("capture.zig");
pub const float = @import("float.zig");
pub const debug = @import("debug.zig");
pub const dump = @import("dump.zig");

pub const capture_from_frame = capture.capture_from_frame;
pub const capture_segments = capture.capture_segments;
pub const capture_float = float.capture;
pub const restore_float = float.restore;
pub const capture_debug = debug.capture;
pub const restore_debug = debug.restore;
pub const dump_context = dump.dump_context;
