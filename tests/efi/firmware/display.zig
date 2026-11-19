//! Firmware Diagnostic Viewport And Pool Ownership

const std = @import("std");

const efi = @import("hikari").efi;
const font = @import("shared").font;
const gop = @import("hikari").sequence.graphics;
const graphics = @import("shared").graphics;
const phase = @import("tests").phase;
const screen = @import("tests").screen;
const types = @import("tests").efi.types.firmware.display;

const BootServices = efi.types.services.boot.BootServices;
const Row = screen.types.model.Row;
const Scratch = types.Scratch;
const Surface = graphics.types.surface.Surface;

var active: ?types.Session = null;
var pool: efi.types.buffer.PoolClaim = .{};
var pool_services: ?*BootServices = null;

pub fn start(services: *BootServices, offer: phase.types.live.Offer, cancel_ready: bool) !void {
    var surface = locateSurface(services) orelse return error.FirmwareViewportUnavailable;
    const layout = screen.layout.plan(surface.Width, surface.Height) orelse return error.FirmwareViewportUnavailable;
    const face = try font.face.load(graphics.assets.font.HIKARI);

    comptime std.debug.assert(@sizeOf(Scratch) % @alignOf(Row) == 0 and @sizeOf(Row) % @alignOf(u32) == 0);
    const pixel_count = try std.math.mul(usize, layout.Width, layout.Height);
    const pixel_bytes = try std.math.mul(usize, pixel_count, @sizeOf(u32));
    const row_bytes = try std.math.mul(usize, layout.VisibleRows, @sizeOf(Row));
    const pixel_offset = try std.math.add(usize, @sizeOf(Scratch), row_bytes);
    const byte_count = try std.math.add(usize, pixel_offset, pixel_bytes);
    pool_services = services;
    if (!efi.buffer.allocatePool(services, byte_count, &pool)) return error.FirmwareViewportAllocationFailed;
    const backing = pool.Allocation.?;
    const scratch: *Scratch = @ptrCast(backing);
    const rows = @as([*]Row, @ptrCast(@alignCast(backing + @sizeOf(Scratch))))[0..layout.VisibleRows];
    const pixels = @as([*]u32, @ptrCast(@alignCast(backing + pixel_offset)))[0..pixel_count];
    scratch.Renderer = scratch.Workspace.bind();

    var progress = screen.live.initialize(rows, offer);
    if (!screen.model.begin(&progress, screen.live.name(.Firmware))) return error.FirmwareViewportProgressInvalid;
    progress.CancelReady = cancel_ready;
    if (!screen.render.takeover(&surface, layout, pixels, .{ .Face = &face, .Renderer = &scratch.Renderer }, &progress, &offer.Date)) return error.FirmwareViewportRenderFailed;
    active = .{ .Surface = surface, .Layout = layout, .Face = face, .Scratch = scratch, .Pixels = pixels, .Progress = progress };
}

pub fn record(name: []const u8) void {
    if (active) |*session| screen.model.evidence(&session.Progress, .Pass, name);
}

pub fn refresh() void {
    if (active) |*session| {
        session.Frame +%= 1;
        const text: screen.types.render.Text = .{ .Face = &session.Face, .Renderer = &session.Scratch.Renderer };
        if (!screen.render.update(&session.Surface, session.Layout, session.Pixels, text, &session.Progress, session.Frame)) active = null;
    }
}

pub fn showFailure(reason: []const u8) void {
    if (active) |*session| {
        screen.model.evidence(&session.Progress, .Fail, reason);
        session.Progress.Active = null;
        session.Progress.ActiveVerified = null;
        refresh();
    }
}

pub fn release() bool {
    active = null;
    const services = pool_services orelse return true;
    if (!efi.buffer.releasePool(services, &pool)) return false;
    pool_services = null;
    return true;
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
