const std = @import("std");

// Akiba magic signature
const AKIBA_MAGIC = [8]u8{ 'A', 'K', 'I', 'B', 'A', 'E', 'L', 'F' };
const AKIBA_VERSION: u32 = 1;

// Executable types
const AKIBA_TYPE_CLI: u32 = 0;
const AKIBA_TYPE_GUI: u32 = 1;
const AKIBA_TYPE_SERVICE: u32 = 2;
const AKIBA_TYPE_LIBRARY: u32 = 3;

// Akiba executable header (64 bytes)
const AkibaHeader = extern struct {
    magic: [8]u8,
    version: u32,
    exec_type: u32,
    elf_offset: u64,
    elf_size: u64,
    metadata_offset: u64,
    metadata_size: u64,
    entry_point: u64,
    reserved: [16]u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 3) {
        std.debug.print("Usage: akibabuilder <input.elf> <output.akiba> [type]\n", .{});
        std.debug.print("Types: cli (default), gui, service, library\n", .{});
        return;
    }

    const input_path = args[1];
    const output_path = args[2];
    const exec_type = if (args.len >= 4) parse_type(args[3]) else AKIBA_TYPE_CLI;

    try wrap_elf(allocator, input_path, output_path, exec_type);
}

fn parse_type(type_str: []const u8) u32 {
    if (std.mem.eql(u8, type_str, "gui")) return AKIBA_TYPE_GUI;
    if (std.mem.eql(u8, type_str, "service")) return AKIBA_TYPE_SERVICE;
    if (std.mem.eql(u8, type_str, "library")) return AKIBA_TYPE_LIBRARY;
    return AKIBA_TYPE_CLI;
}

fn wrap_elf(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, exec_type: u32) !void {
    // Read ELF file
    const elf_data = try std.fs.cwd().readFileAlloc(allocator, input_path, 10 * 1024 * 1024);
    defer allocator.free(elf_data);

    std.debug.print("Read {d} bytes from {s}\n", .{ elf_data.len, input_path });

    // Parse ELF to get entry point
    const entry_point = try parse_elf_entry(elf_data);
    std.debug.print("Entry point: 0x{X:0>16}\n", .{entry_point});

    // Create Akiba header
    const header = AkibaHeader{
        .magic = AKIBA_MAGIC,
        .version = AKIBA_VERSION,
        .exec_type = exec_type,
        .elf_offset = @sizeOf(AkibaHeader),
        .elf_size = elf_data.len,
        .metadata_offset = 0,
        .metadata_size = 0,
        .entry_point = entry_point,
        .reserved = [_]u8{0} ** 16,
    };

    // Write output file
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();

    // Write header as bytes
    const header_bytes = std.mem.asBytes(&header);
    try output_file.writeAll(header_bytes);

    // Write ELF data
    try output_file.writeAll(elf_data);

    std.debug.print("Created {s} ({d} bytes)\n", .{ output_path, header_bytes.len + elf_data.len });
    std.debug.print("Type: {s}\n", .{type_name(exec_type)});
}

fn parse_elf_entry(elf_data: []const u8) !u64 {
    if (elf_data.len < 32) return error.TooSmall;

    // ELF magic check
    if (elf_data[0] != 0x7F or elf_data[1] != 'E' or elf_data[2] != 'L' or elf_data[3] != 'F') {
        return error.NotELF;
    }

    // Check 64-bit
    if (elf_data[4] != 2) {
        return error.Not64Bit;
    }

    // Entry point is at offset 24 for ELF64
    const entry_bytes = elf_data[24..32];
    return std.mem.readInt(u64, entry_bytes[0..8], .little);
}

fn type_name(exec_type: u32) []const u8 {
    return switch (exec_type) {
        AKIBA_TYPE_CLI => "CLI",
        AKIBA_TYPE_GUI => "GUI",
        AKIBA_TYPE_SERVICE => "Service",
        AKIBA_TYPE_LIBRARY => "Library",
        else => "Unknown",
    };
}
