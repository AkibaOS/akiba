//! Checked Native Page Construction Cases

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const fixturetext = @import("tests").fixtures.strings.elf.identities;
const inputs = @import("tests").fixtures.constants.elf.layout;
const weaver = @import("weaver");

const ALLOCATOR = std.testing.allocator;
const EXECUTABLE_BIAS: u64 = 0x100200000;
const LIBRARY_BIAS: u64 = 0x400000;
const RELOCATION = inputs.PAGE_BYTES + inputs.DYNAMIC_RELA;
const TABLE = inputs.PAGE_BYTES + inputs.DYNAMIC_TABLE;
const FILE_BYTE = 0xa5;
const CODE_BYTE = 0x3c;

pub fn verify(sparse: bool) !void {
    var executable = dynamic.loadImage();
    fixture.write64(&executable, fixture.program(0) + 40, 0x1f00);
    const code_address: u64 = if (sparse) 0x9000 else 0x7000;
    fixture.write64(&executable, fixture.program(2) + 16, code_address);
    fixture.write64(&executable, 24, code_address + 1);
    if (sparse) addFragment(&executable);
    executable[0x12b0] = FILE_BYTE;
    executable[2 * inputs.PAGE_BYTES] = CODE_BYTE;
    encodeRelative(&executable, 0x5ffc);
    var library = dynamic.loadImage();
    fixture.write64(&library, TABLE, 21);
    fixture.write64(&library, TABLE + 8, 0);
    library[2 * inputs.PAGE_BYTES] = CODE_BYTE;
    encodeRelative(&library, 0x53f0);
    var graph = try weaver.library.load.collect.collect(ALLOCATOR, .{ .Context = &library, .ReadFromOrigin = read }, &executable);
    defer graph.deinit();
    const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
    var placement = try weaver.image.place.place(ALLOCATOR, &graph, .{ .Executable = EXECUTABLE_BIAS, .Libraries = &.{LIBRARY_BIAS} }, policy, &.{});
    defer placement.deinit();
    var linked = try weaver.link.plan.plan(ALLOCATOR, &placement);
    defer linked.deinit();
    var stream: weaver.stage.types.page.stream.Stream = .{ .Link = &linked };
    var bytes: [inputs.PAGE_BYTES]u8 = @splat(0xff);
    const next = weaver.stage.page.next.next;
    const relro = next(&stream, &bytes) orelse return error.MissingPage;
    try std.testing.expectEqual(@as(u64, 0x100205000), relro.Address);
    try std.testing.expectEqual(.ReadOnly, relro.Access);
    try std.testing.expectEqual(@as(?usize, null), relro.LibraryIndex);
    try std.testing.expect(!relro.ImmutableLibrary);
    try std.testing.expect(std.mem.allEqual(u8, bytes[0..0x80], 0));
    try std.testing.expectEqual(@as(u8, if (sparse) 0x69 else 0), bytes[0x80]);
    try std.testing.expect(std.mem.allEqual(u8, bytes[0x81..0x100], 0));
    try std.testing.expectEqual(@as(u8, FILE_BYTE), bytes[0x2b0]);
    try std.testing.expect(std.mem.allEqual(u8, bytes[0x2c0..0xffc], 0));
    try std.testing.expectEqualSlices(u8, &.{ 0x00, 0x54, 0x20, 0x00 }, bytes[0xffc..]);
    const writable = next(&stream, &bytes) orelse return error.MissingPage;
    try std.testing.expectEqual(@as(u64, 0x100206000), writable.Address);
    try std.testing.expectEqual(.ReadWrite, writable.Access);
    try std.testing.expectEqualSlices(u8, &.{ 0x01, 0x00, 0x00, 0x00 }, bytes[0..4]);
    try std.testing.expect(std.mem.allEqual(u8, bytes[4..], 0));
    const code = next(&stream, &bytes) orelse return error.MissingPage;
    try std.testing.expectEqual(@as(u64, if (sparse) 0x100209000 else 0x100207000), code.Address);
    try std.testing.expectEqual(.ReadExecute, code.Access);
    try std.testing.expect(!code.ImmutableLibrary);
    try std.testing.expectEqual(@as(u8, CODE_BYTE), bytes[0]);
    try std.testing.expect(std.mem.allEqual(u8, bytes[32..], 0));
    const library_relro = next(&stream, &bytes) orelse return error.MissingPage;
    try std.testing.expectEqual(@as(u64, 0x405000), library_relro.Address);
    try std.testing.expectEqual(.ReadOnly, library_relro.Access);
    try std.testing.expect(!library_relro.ImmutableLibrary);
    try std.testing.expectEqual(@as(u64, 0x405400), std.mem.readInt(u64, bytes[0x3f0..][0..8], .little));
    const library_code = next(&stream, &bytes) orelse return error.MissingPage;
    try std.testing.expectEqual(@as(u64, 0x406000), library_code.Address);
    try std.testing.expectEqual(.ReadExecute, library_code.Access);
    try std.testing.expectEqual(@as(?usize, 0), library_code.LibraryIndex);
    try std.testing.expect(library_code.ImmutableLibrary);
    try std.testing.expectEqual(@as(u8, CODE_BYTE), bytes[0]);
    try std.testing.expect(next(&stream, &bytes) == null and next(&stream, &bytes) == null);
    try std.testing.expectEqualSlices(u8, &executable, graph.Executable);
    try std.testing.expectEqualSlices(u8, &library, graph.Libraries[0].Bytes);
}

fn addFragment(bytes: []u8) void {
    fixture.write16(bytes, 56, 5);
    const extra = fixture.program(4);
    @memset(bytes[extra..][0..inputs.PROGRAM_BYTES], 0);
    fixture.write32(bytes, extra, 1);
    fixture.write32(bytes, extra + 4, 4);
    fixture.write64(bytes, extra + 8, 0x1080);
    fixture.write64(bytes, extra + 16, 0x5080);
    fixture.write64(bytes, extra + 32, 1);
    fixture.write64(bytes, extra + 40, 1);
    fixture.write64(bytes, extra + 48, inputs.PAGE_BYTES);
    bytes[0x1080] = 0x69;
}

fn encodeRelative(bytes: []u8, address: u64) void {
    fixture.write64(bytes, RELOCATION, address);
    fixture.write64(bytes, RELOCATION + 16, 0x5400);
    fixture.write64(bytes, TABLE + 11 * inputs.DYNAMIC_WORD_BYTES + 8, 0);
}

fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, name: []const u8) weaver.library.errors.library.ReadError!?[]u8 {
    const library: *const [inputs.DATA_BYTES]u8 = @ptrCast(@alignCast(context));
    if (parent.len != 2 or !std.mem.eql(u8, parent[0], "system") or !std.mem.eql(u8, parent[1], "libraries") or !std.mem.eql(u8, name, fixturetext.DYNAMIC_LIBRARY)) return null;
    return try allocator.dupe(u8, library);
}
