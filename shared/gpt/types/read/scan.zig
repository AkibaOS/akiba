//! Streaming GPT Table Evidence

const std = @import("std");

const fields = @import("shared").gpt.constants.read.entry;

const Volume = @import("shared").boot.types.volume.Volume;
const Window = @import("shared").gpt.types.read.window.Window;

pub const State = enum { Missing, Mismatch, Matched, Ambiguous };

pub const Scan = struct {
    Volume: Volume,
    Window: Window,
    Remaining: u64,
    CRC: std.hash.Crc32 = std.hash.Crc32.init(),
    Prefix: [fields.PREFIX_BYTES]u8 = undefined,
    Offset: usize = 0,
    Match: State = .Missing,
    Discover: bool = false,
};
