//! Compose File Bytes And Relocations In One Scratch Page

const std = @import("std");

const elf = @import("shared").elf;
const sizes = @import("common").constants.memory.sizes;
const types = @import("weaver").stage.types.page;

const Program = elf.types.format.Elf64ProgramHeader;
const Stream = types.Stream;
const View = types.View;
const Write = elf.types.relocation.Write;

const WORD_BYTES = @sizeOf(u64);

pub fn fill(stream: *Stream, view: View, address: u64, buffer: *[sizes.PAGE_SIZE]u8) void {
    @memset(buffer, 0);
    const end = address + sizes.PAGE_SIZE;
    files(stream, view, address, end, buffer);
    writes(stream, view.Writes, address, end, buffer);
}

fn files(stream: *Stream, view: View, address: u64, end: u64, buffer: *[sizes.PAGE_SIZE]u8) void {
    const segments = view.Layout.Image.Segments;
    while (stream.SegmentIndex < segments.len and fileEnd(segments[stream.SegmentIndex]) <= address) stream.SegmentIndex += 1;
    for (segments[stream.SegmentIndex..]) |segment| {
        if (segment.VirtualAddress >= end) break;
        const start = @max(address, segment.VirtualAddress);
        const limit = @min(end, fileEnd(segment));
        if (start >= limit) continue;
        const offset: usize = @intCast(segment.Offset + (start - segment.VirtualAddress));
        const destination: usize = @intCast(start - address);
        const length: usize = @intCast(limit - start);
        @memcpy(buffer[destination..][0..length], view.Bytes[offset..][0..length]);
    }
}

fn writes(stream: *Stream, entries: []const Write, address: u64, end: u64, buffer: *[sizes.PAGE_SIZE]u8) void {
    while (stream.WriteIndex < entries.len and entries[stream.WriteIndex].Address + WORD_BYTES <= address) stream.WriteIndex += 1;
    for (entries[stream.WriteIndex..]) |entry| {
        if (entry.Address >= end) break;
        const start = @max(address, entry.Address);
        const limit = @min(end, entry.Address + WORD_BYTES);
        const length: usize = @intCast(limit - start);
        const offset: usize = @intCast(start - entry.Address);
        const destination: usize = @intCast(start - address);
        var bytes: [WORD_BYTES]u8 = undefined;
        std.mem.writeInt(u64, &bytes, entry.Value, .little);
        @memcpy(buffer[destination..][0..length], bytes[offset..][0..length]);
    }
}

fn fileEnd(segment: Program) u64 {
    return segment.VirtualAddress + segment.UnitSize;
}
