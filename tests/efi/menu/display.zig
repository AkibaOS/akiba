//! EFI Diagnostic Suite Summary Rendering

const std = @import("std");

const efi = @import("hikari").efi;
const font = @import("shared").font;
const format = @import("common").constants.serial.format;
const gop = @import("hikari").sequence.graphics;
const graphics = @import("shared").graphics;
const labels = @import("tests").efi.strings.menu.summary;
const phase = @import("tests").phase;
const screen = @import("tests").screen;
const splash = @import("shared").splash;

const BootServices = efi.types.services.boot.BootServices;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Surface = graphics.types.surface.Surface;
const View = @import("tests").efi.types.menu.display.View;
const Workspace = splash.types.workspace.Workspace;

pub fn show(services: *BootServices, offer: phase.types.menu.Offer, view: *View) bool {
    const target = locateSurface(services) orelse return false;
    const layout = screen.layout.plan(target.Width, target.Height) orelse return false;
    const pixel_count = std.math.mul(usize, layout.Width, layout.Height) catch return false;
    const pixel_bytes = std.math.mul(usize, pixel_count, @sizeOf(u32)) catch return false;
    const scratch_bytes = std.math.add(usize, @sizeOf(Workspace), pixel_bytes) catch return false;
    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;

    var primary: [labels.SUITE_PASSED.len + format.MAX_DECIMAL_DIGITS]u8 = undefined;
    var verified: [labels.VERIFIED_CHECKS.len + format.MAX_DECIMAL_DIGITS]u8 = undefined;
    var failures: [labels.PHASE_FAILURES.len + 2 * format.MAX_DECIMAL_DIGITS]u8 = undefined;
    var rows: [3 + phase.constants.menu.PHASE_COUNT]screen.types.model.Row = undefined;
    const count: usize = if (offer.FailedMask == 0) success: {
        const message = std.fmt.bufPrint(&primary, labels.SUITE_PASSED, .{offer.Passed}) catch return false;
        rows[0] = .{ .Kind = .Pass, .Text = message };
        break :success 1;
    } else failed: {
        const checks = std.fmt.bufPrint(&verified, labels.VERIFIED_CHECKS, .{offer.Passed}) catch return false;
        const phases = std.fmt.bufPrint(&failures, labels.PHASE_FAILURES, .{ @popCount(offer.FailedMask), @popCount(offer.InterruptedMask) }) catch return false;
        rows[0] = .{ .Kind = .Fail, .Text = labels.SUITE_FAILED };
        rows[1] = .{ .Kind = .Info, .Text = checks };
        rows[2] = .{ .Kind = .Info, .Text = phases };
        break :failed 3 + failedRows(rows[3..], offer);
    };
    const snapshot: screen.types.model.Model = .{
        .Rows = rows[0..count],
        .Total = phase.constants.live.TOTAL_UNITS,
        .Count = count,
        .Completed = phase.menu.completedUnits(offer),
        .Failed = @popCount(offer.FailedMask),
        .Work = offer.Work,
        .Done = true,
        .MenuReady = true,
    };

    if (!efi.buffer.allocatePool(services, scratch_bytes, &view.Pool)) return false;
    const backing = view.Pool.Allocation.?;
    const workspace: *Workspace = @ptrCast(backing);
    view.Target = target;
    view.Layout = layout;
    view.Face = face;
    view.Renderer = workspace.bind();
    view.Pixels = @as([*]u32, @ptrCast(@alignCast(backing + @sizeOf(Workspace))))[0..pixel_count];
    return screen.render.takeover(&view.Target, view.Layout, view.Pixels, textContext(view), &snapshot, &offer.Date);
}

pub fn updateCountdown(view: *View, seconds: u8) bool {
    if (view.Pool.Allocation == null) return false;
    return screen.render.updateCountdown(&view.Target, view.Layout, view.Pixels, textContext(view), seconds);
}

pub fn release(services: *BootServices, view: *View) bool {
    return efi.buffer.releasePool(services, &view.Pool);
}

fn textContext(view: *View) screen.types.render.Text {
    return .{ .Face = &view.Face, .Renderer = &view.Renderer };
}

fn failedRows(rows: []screen.types.model.Row, offer: phase.types.menu.Offer) usize {
    var count: usize = 0;
    for (std.enums.values(Scenario)) |selected| {
        const name = switch (phase.menu.phaseStatus(offer, selected)) {
            .Passed => continue,
            .Failed => screen.live.name(selected),
            .Incomplete => screen.live.incompleteName(selected),
        };
        rows[count] = .{ .Kind = .Fail, .Text = name };
        count += 1;
    }
    return count;
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
