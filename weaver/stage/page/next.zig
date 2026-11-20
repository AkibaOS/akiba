//! Stream The Checked Native Images With Final Page Rights

const fill = @import("weaver").stage.page.fill;
const format = @import("shared").elf.constants.format;
const sizes = @import("common").constants.memory.sizes;
const types = @import("weaver").stage.types.page.stream;

const Access = types.Access;
const Page = types.Page;
const Relro = @import("shared").elf.types.dynamic.Relro;
const Stream = types.Stream;
const View = types.View;

pub fn next(stream: *Stream, buffer: *[sizes.PAGE_SIZE]u8) ?Page {
    while (stream.ImageIndex <= stream.Link.Libraries.len) {
        const view = image(stream);
        const ranges = view.Layout.Image.Ranges;
        if (stream.RangeIndex == ranges.len) {
            stream.* = .{ .Link = stream.Link, .ImageIndex = stream.ImageIndex + 1 };
            continue;
        }
        const range = ranges[stream.RangeIndex];
        const address = @max(stream.Address, range.Start);
        fill.fill(stream, view, address, buffer);
        stream.Address = address + sizes.PAGE_SIZE;
        if (stream.Address == range.End) stream.RangeIndex += 1;
        const library_index: ?usize = if (stream.ImageIndex == 0) null else stream.ImageIndex - 1;
        return .{
            .Address = address,
            .Access = access(range.Flags, view.Layout.Relro, address),
            .LibraryIndex = library_index,
            .ImmutableLibrary = library_index != null and range.Flags & format.SEGMENT_FLAG_WRITE == 0,
        };
    }
    return null;
}

fn image(stream: *const Stream) View {
    const placement = stream.Link.Placement;
    if (stream.ImageIndex == 0) return .{
        .Bytes = placement.Graph.Executable,
        .Layout = &placement.Executable,
        .Writes = stream.Link.Executable.Writes,
    };
    const library = stream.ImageIndex - 1;
    return .{
        .Bytes = placement.Graph.Libraries[library].Bytes,
        .Layout = &placement.Libraries[library],
        .Writes = stream.Link.Libraries[library].Writes,
    };
}

fn access(flags: u32, relro: ?Relro, address: u64) Access {
    if (flags & format.SEGMENT_FLAG_EXECUTE != 0) return .ReadExecute;
    if (relro) |range| if (address >= range.Start and address < range.End) return .ReadOnly;
    return if (flags & format.SEGMENT_FLAG_WRITE != 0) .ReadWrite else .ReadOnly;
}
