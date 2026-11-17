//! Exclusively Owned Atomic Disk Image Output

const std = @import("std");

const tool = @import("mkafsdisk");

pub const Output = struct {
    Atomic: std.fs.AtomicFile,
    ExpectedBytes: u64,

    pub fn file(self: *const Output) std.fs.File {
        return self.Atomic.file_writer.file;
    }

    pub fn finish(self: *Output) !void {
        const destination = self.file();
        if (try destination.getEndPos() != self.ExpectedBytes) return tool.errors.image.ImageError.ImageSizeMismatch;
        try destination.sync();
        try self.Atomic.finish();
    }

    pub fn deinit(self: *Output) void {
        self.Atomic.deinit();
        self.* = undefined;
    }
};
