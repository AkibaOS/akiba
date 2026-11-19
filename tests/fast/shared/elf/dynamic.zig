//! Independently Encoded Dynamic ELF Reader Cases

const std = @import("std");

const elf = @import("shared").elf;
const fixture = @import("tests").fast.shared.elf.fixture;
const inputs = @import("tests").constants.elf;
const text = @import("tests").strings.elf;

pub fn readsTables() !void {
    var bytes = image();
    const metadata = try elf.read.dynamic.read(&bytes);
    try std.testing.expectEqual(inputs.DYNAMIC_WORDS - 1, metadata.Entries.len);
    try std.testing.expectEqualStrings(text.DYNAMIC_LIBRARY, try metadata.string(metadata.Entries[0].Value));
    try std.testing.expectEqualStrings(text.DYNAMIC_LIBRARY, try metadata.string(metadata.Entries[1].Value));
    try std.testing.expectEqual(@as(usize, 2), metadata.Symbols.len);
    try std.testing.expectEqualStrings(text.DYNAMIC_EXPORT, try metadata.string(metadata.Symbols[1].NameOffset));
    try std.testing.expectEqual(@as(usize, 1), metadata.Relocations.len);
    try std.testing.expectEqual(@as(u64, 8), metadata.Relocations[0].Info);
    try std.testing.expectEqual(@as(i64, 19), metadata.Relocations[0].Addend);
    try std.testing.expectEqual(@as(usize, 1), metadata.ProcedureRelocations.len);
    try std.testing.expectEqual(@as(u64, (1 << 32) | 7), metadata.ProcedureRelocations[0].Info);
    word(&bytes, 1, 1, 1);
    const repeated = try elf.read.dynamic.read(&bytes);
    try std.testing.expectEqual(@as(i64, 1), repeated.Entries[1].Tag);
}

pub fn checksBacking() !void {
    const source = image();
    var bytes = source;
    word(&bytes, 2, 5, inputs.DYNAMIC_BASE + inputs.DYNAMIC_FILE_BYTES);
    try std.testing.expectError(error.InvalidDynamicAddress, elf.read.dynamic.read(&bytes));
    try std.testing.expectError(error.InvalidDynamicAddress, elf.read.dynamic.read(source[0 .. inputs.DYNAMIC_FILE_BASE + inputs.DYNAMIC_FILE_BYTES - 1]));
    bytes = source;
    fixture.write64(&bytes, fixture.program(1) + 8, inputs.DYNAMIC_TABLE + 16);
    try std.testing.expectError(error.InvalidDynamic, elf.read.dynamic.read(&bytes));
    bytes = source;
    fixture.write16(&bytes, 56, 3);
    @memcpy(bytes[fixture.program(2)..][0..inputs.PROGRAM_BYTES], bytes[fixture.program(0)..][0..inputs.PROGRAM_BYTES]);
    try std.testing.expectError(error.InvalidDynamicAddress, elf.read.dynamic.read(&bytes));
}

pub fn checksNames() !void {
    const source = image();
    var bytes = source;
    word(&bytes, 0, 1, text.DYNAMIC_STRINGS.len);
    try std.testing.expectError(error.InvalidDynamicString, elf.read.dynamic.read(&bytes));
    bytes = source;
    bytes[inputs.DYNAMIC_FILE_BASE + text.DYNAMIC_STRINGS.len - 1] = 'x';
    try std.testing.expectError(error.InvalidDynamicString, elf.read.dynamic.read(&bytes));
    bytes = source;
    fixture.write32(&bytes, inputs.DYNAMIC_SYMBOLS + inputs.DYNAMIC_SYMBOL_BYTES, text.DYNAMIC_STRINGS.len);
    try std.testing.expectError(error.InvalidDynamicString, elf.read.dynamic.read(&bytes));
    bytes = source;
    word(&bytes, 1, 5, inputs.DYNAMIC_BASE);
    try std.testing.expectError(error.InvalidDynamic, elf.read.dynamic.read(&bytes));
}

pub fn checksTableExtents() !void {
    const source = image();
    var bytes = source;
    word(&bytes, inputs.DYNAMIC_WORDS - 1, 1, 1);
    try std.testing.expectError(error.InvalidDynamic, elf.read.dynamic.read(&bytes));
    bytes = source;
    fixture.write32(&bytes, inputs.DYNAMIC_HASH + 4, std.math.maxInt(u32));
    try std.testing.expectError(error.InvalidDynamicAddress, elf.read.dynamic.read(&bytes));
    bytes = source;
    word(&bytes, 8, 8, inputs.DYNAMIC_RELA_BYTES + 1);
    try std.testing.expectError(error.InvalidDynamic, elf.read.dynamic.read(&bytes));
    bytes = source;
    fixture.write64(&bytes, inputs.DYNAMIC_PLT + 8, (2 << 32) | 7);
    try std.testing.expectError(error.InvalidDynamic, elf.read.dynamic.read(&bytes));
    bytes = source;
    word(&bytes, 12, 20, 17);
    try std.testing.expectError(error.UnsupportedDynamic, elf.read.dynamic.read(&bytes));
    bytes = source;
    fixture.write16(&bytes, 56, 3);
    fixture.write32(&bytes, fixture.program(2), 3);
    try std.testing.expectError(error.UnsupportedDynamic, elf.read.dynamic.read(&bytes));
}

const POLICY: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };

pub fn placesImage() !void {
    const bytes = loadImage();
    var executable = try elf.validate.dynamic.parse(std.testing.allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY);
    defer executable.Image.deinit();
    try std.testing.expectEqual(inputs.DYNAMIC_BIAS + inputs.DYNAMIC_LAYOUT_CODE + 1, executable.Image.Entry);
    try std.testing.expectEqual(@as(u64, 2), executable.Image.Pages);
    try std.testing.expectEqual(inputs.DYNAMIC_LAYOUT_FILE, executable.Image.Segments[0].Offset);
    try std.testing.expectEqual(inputs.DYNAMIC_BIAS + inputs.DYNAMIC_LAYOUT_DATA, executable.Image.Segments[0].VirtualAddress);
    try std.testing.expectEqual(@as(u32, 6), executable.Image.Ranges[0].Flags);
    try std.testing.expectEqual(inputs.DYNAMIC_BIAS + inputs.DYNAMIC_BASE, executable.Relro.?.Start);
    try std.testing.expectEqual(inputs.DYNAMIC_BIAS + inputs.DYNAMIC_LAYOUT_CODE, executable.Relro.?.End);
    var library = try elf.validate.dynamic.parse(std.testing.allocator, &bytes, inputs.DYNAMIC_BIAS, .Library, POLICY);
    defer library.Image.deinit();
    try std.testing.expectEqual(@as(u64, 0), library.Image.Entry);
}

pub fn rejectsInvalidLayout() !void {
    const source = loadImage();
    const parse = elf.validate.dynamic.parse;
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.InvalidPolicy, parse(allocator, &source, inputs.DYNAMIC_BIAS + 8, .Executable, POLICY));
    var bytes = source;
    fixture.write64(&bytes, 24, inputs.DYNAMIC_LAYOUT_CODE + inputs.DYNAMIC_LAYOUT_CODE_BYTES);
    try std.testing.expectError(error.InvalidEntryPoint, parse(allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY));
    bytes = source;
    fixture.write32(&bytes, fixture.program(2) + 4, 7);
    try std.testing.expectError(error.InvalidSegment, parse(allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY));
    bytes = source;
    fixture.write16(&bytes, 56, 5);
    fixture.write32(&bytes, fixture.program(4), 7);
    try std.testing.expectError(error.UnsupportedSegment, parse(allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY));
}

pub fn rejectsUnsafeRelro() !void {
    const source = loadImage();
    const parse = elf.validate.dynamic.parse;
    const allocator = std.testing.allocator;
    const relro = fixture.program(3);
    const extent = inputs.DYNAMIC_LAYOUT_CODE - inputs.DYNAMIC_LAYOUT_DATA;
    var bytes = source;
    fixture.write64(&bytes, relro + 40, extent - 1);
    try std.testing.expectError(error.InvalidRelro, parse(allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY));
    bytes = source;
    fixture.write64(&bytes, relro + 8, inputs.DYNAMIC_LAYOUT_FILE + 8);
    fixture.write64(&bytes, relro + 16, inputs.DYNAMIC_LAYOUT_DATA + 8);
    fixture.write64(&bytes, relro + 32, inputs.DYNAMIC_FILE_BYTES - 8);
    fixture.write64(&bytes, relro + 40, extent - 8);
    try std.testing.expectError(error.InvalidRelro, parse(allocator, &bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY));
}

pub fn loadImage() [inputs.DATA_BYTES]u8 {
    var bytes = image();
    const file = inputs.DYNAMIC_LAYOUT_FILE;
    @memcpy(bytes[file..][0..inputs.DYNAMIC_FILE_BYTES], bytes[inputs.DYNAMIC_FILE_BASE..][0..inputs.DYNAMIC_FILE_BYTES]);
    fixture.write16(&bytes, 56, 4);
    fixture.write64(&bytes, 24, inputs.DYNAMIC_LAYOUT_CODE + 1);
    const extent = inputs.DYNAMIC_LAYOUT_CODE - inputs.DYNAMIC_LAYOUT_DATA;
    program(&bytes, 0, 1, file, inputs.DYNAMIC_FILE_BYTES, extent);
    fixture.write64(&bytes, fixture.program(0) + 16, inputs.DYNAMIC_LAYOUT_DATA);
    fixture.write64(&bytes, fixture.program(0) + 48, inputs.PAGE_BYTES);
    const table_offset = inputs.DYNAMIC_TABLE - inputs.DYNAMIC_FILE_BASE;
    const table_size = inputs.DYNAMIC_WORD_BYTES * inputs.DYNAMIC_WORDS;
    program(&bytes, 1, 2, file + table_offset, table_size, table_size);
    fixture.write64(&bytes, fixture.program(1) + 16, inputs.DYNAMIC_LAYOUT_DATA + table_offset);
    program(&bytes, 2, 1, 2 * inputs.PAGE_BYTES, inputs.DYNAMIC_LAYOUT_CODE_BYTES, inputs.DYNAMIC_LAYOUT_CODE_BYTES);
    fixture.write32(&bytes, fixture.program(2) + 4, 5);
    fixture.write64(&bytes, fixture.program(2) + 16, inputs.DYNAMIC_LAYOUT_CODE);
    fixture.write64(&bytes, fixture.program(2) + 48, inputs.PAGE_BYTES);
    program(&bytes, 3, 0x6474e552, file, inputs.DYNAMIC_FILE_BYTES, extent);
    fixture.write32(&bytes, fixture.program(3) + 4, 4);
    fixture.write64(&bytes, fixture.program(3) + 16, inputs.DYNAMIC_LAYOUT_DATA);
    fixture.write64(&bytes, fixture.program(3) + 48, 1);
    for ([_]usize{ 2, 4, 6, 7, 10 }) |index| {
        const offset = file + table_offset + index * inputs.DYNAMIC_WORD_BYTES + @sizeOf(u64);
        const value = std.mem.readInt(u64, bytes[offset..][0..@sizeOf(u64)], .little);
        fixture.write64(&bytes, offset, value + inputs.DYNAMIC_FILE_BASE);
    }
    return bytes;
}

fn image() [inputs.DATA_BYTES]u8 {
    var bytes = fixture.create();
    @memset(bytes[inputs.DYNAMIC_FILE_BASE .. inputs.DYNAMIC_FILE_BASE + inputs.DYNAMIC_MEMORY_BYTES], 0);
    fixture.write16(&bytes, 16, 3);
    fixture.write64(&bytes, 24, 0);
    fixture.write16(&bytes, 56, 2);
    program(&bytes, 0, 1, inputs.DYNAMIC_FILE_BASE, inputs.DYNAMIC_FILE_BYTES, inputs.DYNAMIC_MEMORY_BYTES);
    const table_bytes = inputs.DYNAMIC_WORD_BYTES * inputs.DYNAMIC_WORDS;
    program(&bytes, 1, 2, inputs.DYNAMIC_TABLE, table_bytes, table_bytes);
    @memcpy(bytes[inputs.DYNAMIC_FILE_BASE..][0..text.DYNAMIC_STRINGS.len], text.DYNAMIC_STRINGS);
    fixture.write32(&bytes, inputs.DYNAMIC_SYMBOLS + inputs.DYNAMIC_SYMBOL_BYTES, 11);
    bytes[inputs.DYNAMIC_SYMBOLS + inputs.DYNAMIC_SYMBOL_BYTES + 4] = 0x12;
    fixture.write32(&bytes, inputs.DYNAMIC_HASH, 1);
    fixture.write32(&bytes, inputs.DYNAMIC_HASH + 4, 2);
    fixture.write32(&bytes, inputs.DYNAMIC_HASH + 8, 1);
    fixture.write64(&bytes, inputs.DYNAMIC_RELA, inputs.DYNAMIC_BASE + 64);
    fixture.write64(&bytes, inputs.DYNAMIC_RELA + 8, 8);
    fixture.write64(&bytes, inputs.DYNAMIC_RELA + 16, 19);
    fixture.write64(&bytes, inputs.DYNAMIC_PLT, inputs.DYNAMIC_BASE + 72);
    fixture.write64(&bytes, inputs.DYNAMIC_PLT + 8, (1 << 32) | 7);
    word(&bytes, 0, 1, 1);
    word(&bytes, 1, 14, 1);
    word(&bytes, 2, 5, inputs.DYNAMIC_BASE);
    word(&bytes, 3, 10, text.DYNAMIC_STRINGS.len);
    word(&bytes, 4, 6, address(inputs.DYNAMIC_SYMBOLS));
    word(&bytes, 5, 11, inputs.DYNAMIC_SYMBOL_BYTES);
    word(&bytes, 6, 4, address(inputs.DYNAMIC_HASH));
    word(&bytes, 7, 7, address(inputs.DYNAMIC_RELA));
    word(&bytes, 8, 8, inputs.DYNAMIC_RELA_BYTES);
    word(&bytes, 9, 9, inputs.DYNAMIC_RELA_BYTES);
    word(&bytes, 10, 23, address(inputs.DYNAMIC_PLT));
    word(&bytes, 11, 2, inputs.DYNAMIC_RELA_BYTES);
    word(&bytes, 12, 20, 7);
    return bytes;
}

fn word(bytes: []u8, index: usize, tag: u64, value: u64) void {
    const offset = inputs.DYNAMIC_TABLE + index * inputs.DYNAMIC_WORD_BYTES;
    fixture.write64(bytes, offset, tag);
    fixture.write64(bytes, offset + @sizeOf(u64), value);
}

fn program(bytes: []u8, index: usize, kind: u32, offset: usize, file_bytes: usize, memory_bytes: usize) void {
    const start = fixture.program(index);
    fixture.write32(bytes, start, kind);
    fixture.write32(bytes, start + 4, 6);
    fixture.write64(bytes, start + 8, offset);
    fixture.write64(bytes, start + 16, address(offset));
    fixture.write64(bytes, start + 32, file_bytes);
    fixture.write64(bytes, start + 40, memory_bytes);
    fixture.write64(bytes, start + 48, inputs.DYNAMIC_WORD_BYTES);
}

fn address(offset: usize) u64 {
    return inputs.DYNAMIC_BASE + offset - inputs.DYNAMIC_FILE_BASE;
}
