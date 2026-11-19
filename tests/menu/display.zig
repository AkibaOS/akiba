//! EFI Diagnostic Suite Summary Rendering

const std = @import("std");

const efi = @import("hikari").efi;
const font = @import("shared").font;
const format = @import("common").constants.serial.format;
const gop = @import("hikari").sequence.graphics;
const graphics = @import("shared").graphics;
const labels = @import("menu").strings.summary;
const screen = @import("tests").screen;
const splash = @import("shared").splash;

const BootServices = efi.types.services.boot.BootServices;
const Surface = graphics.types.surface.Surface;
const Workspace = splash.types.workspace.Workspace;

pub fn show(services: *BootServices, passed: u32, date: []const u8) bool {
    if (passed == 0) return false;
    var target = locateSurface(services) orelse return false;
    const layout = screen.layout.plan(target.Width, target.Height) orelse return false;
    const pixel_count = std.math.mul(usize, layout.Width, layout.Height) catch return false;
    const pixel_bytes = std.math.mul(usize, pixel_count, @sizeOf(u32)) catch return false;
    const scratch_bytes = std.math.add(usize, @sizeOf(Workspace), pixel_bytes) catch return false;
    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;

    var summary: [labels.SUITE_PASSED.len + format.MAX_DECIMAL_DIGITS]u8 = undefined;
    const message = std.fmt.bufPrint(&summary, labels.SUITE_PASSED, .{passed}) catch return false;
    var rows = [_]screen.types.model.Row{.{ .Kind = .Pass, .Text = message }};
    const snapshot: screen.types.model.Model = .{
        .Rows = &rows,
        .Total = passed,
        .Count = rows.len,
        .Completed = passed,
        .Done = true,
        .MenuReady = true,
    };

    var scratch: efi.types.buffer.PoolClaim = .{};
    if (!efi.buffer.allocatePool(services, scratch_bytes, &scratch)) return false;
    const backing = scratch.Allocation.?;
    const workspace: *Workspace = @ptrCast(backing);
    const pixels = @as([*]u32, @ptrCast(@alignCast(backing + @sizeOf(Workspace))))[0..pixel_count];
    var renderer = workspace.bind();
    const rendered = screen.render.takeover(&target, layout, pixels, .{ .Face = &face, .Renderer = &renderer }, &snapshot, date);
    const released = efi.buffer.releasePool(services, &scratch);
    return rendered and released;
}

fn locateSurface(services: *BootServices) ?Surface {
    const protocol = gop.getGraphicsOutput(services) orelse return null;
    const mode = protocol.Mode;
    if (mode.Mode >= mode.MaxMode or mode.SizeOfInfo < @sizeOf(efi.types.graphics.GraphicsOutputModeInformation)) return null;
    const info = mode.Info;
    const pixel_format: graphics.types.pixel.PixelFormat = switch (info.PixelFormat) {
        .RGB => .RGB,
        .BGR => .BGR,
        else => return null,
    };
    const base = mode.FramebufferBase;
    const width = info.HorizontalResolution;
    const height = info.VerticalResolution;
    const stride = info.PixelsPerScanLine;
    if (base == 0 or base % @alignOf(u32) != 0 or width == 0 or height == 0 or stride < width) return null;
    const row_bytes = @as(u64, stride) * @sizeOf(u32);
    if (mode.FramebufferSize > std.math.maxInt(u64) - base or height > mode.FramebufferSize / row_bytes) return null;
    return Surface.initialize(base, width, height, stride, pixel_format);
}
