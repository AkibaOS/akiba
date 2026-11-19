//! Standard Guest Screen Controller

const std = @import("std");

const address = @import("utils").address;
const boot = @import("shared").boot;
const common = @import("common");
const control = @import("asm").cpu.constants.control;
const font = @import("shared").font;
const graphics = @import("shared").graphics;
const guard = @import("asm").interrupts.guard;
const pit = @import("mirai").drivers.pit.handler;
const pmm = @import("mirai").pmm;
const rate = @import("mirai").drivers.constants.pit.limits;
const screen = @import("tests").screen;
const splash = @import("shared").splash;
const timer = @import("tests").guest.screen.timer;
const types = @import("tests").guest.screen.types.session;

const Framebuffer = boot.types.framebuffer.FramebufferInfo;
const LiveOffer = @import("tests").phase.types.live.Offer;
const Outcome = screen.types.model.Outcome;
const Row = screen.types.model.Row;
const Session = types.Session;
const page_size = common.constants.memory.sizes.PAGE_SIZE;

var framebuffer: ?Framebuffer = null;
var active: ?Session = null;
var workspace: splash.types.workspace.Workspace = undefined;
var renderer: graphics.types.renderer.TextRenderer = undefined;

pub fn bind(descriptor: Framebuffer) void {
    if (descriptor.isValid()) framebuffer = descriptor;
}

pub fn start(total: usize, date: ?[]const u8, cancel_ready: bool, prior: ?LiveOffer) bool {
    const descriptor = framebuffer orelse return false;
    if (active != null or total == 0) return false;
    const layout = screen.layout.plan(descriptor.Width, descriptor.Height) orelse return false;
    const pixel_count = std.math.mul(usize, layout.Width, layout.Height) catch return false;
    const pixel_bytes = std.math.mul(usize, pixel_count, @sizeOf(u32)) catch return false;
    const row_count = 2 * layout.VisibleRows;
    const row_bytes = std.math.mul(usize, row_count, @sizeOf(Row)) catch return false;
    const aligned_bytes = std.math.add(usize, pixel_bytes, @alignOf(Row) - 1) catch return false;
    const row_offset = aligned_bytes & ~@as(usize, @alignOf(Row) - 1);
    const bytes = std.math.add(usize, row_offset, row_bytes) catch return false;
    const pages = bytes / page_size + @intFromBool(bytes % page_size != 0);
    const face = font.face.load(graphics.assets.font.HIKARI) catch return false;

    const physical = pmm.allocate.contiguous.allocateContiguous(pages) catch return false;
    var owned = false;
    defer if (!owned) pmm.free.range.freeRange(physical, pages);
    const backing: [*]align(page_size) u8 = @ptrFromInt(address.translate.physToVirt(physical));
    const pixels = @as([*]u32, @ptrCast(backing))[0..pixel_count];
    const rows = @as([*]Row, @ptrCast(@alignCast(backing + row_offset)))[0..row_count];

    var surface = graphics.types.surface.Surface.initialize(descriptor.Base, descriptor.Width, descriptor.Height, descriptor.Stride, descriptor.PixelFormat);
    const visible = rows[0..layout.VisibleRows];
    var progress = if (prior) |context| screen.live.initialize(visible, context) else screen.model.initialize(visible, total);
    progress.CancelReady = cancel_ready;
    renderer = workspace.bind();
    if (!screen.render.takeover(&surface, layout, pixels, .{ .Face = &face, .Renderer = &renderer }, &progress, date)) return false;
    active = .{ .Surface = surface, .Layout = layout, .Face = face, .Physical = physical, .Pages = pages, .Pixels = pixels, .Rows = rows, .Progress = progress };
    owned = true;
    return true;
}

pub fn begin(name: []const u8) void {
    const flags = guard.acquire();
    const session = if (active) |*current| current else null;
    const changed = if (session) |current| screen.model.begin(&current.Progress, name) else false;
    if (changed) session.?.Started = pit.getTicks();
    guard.release(flags);
    if (changed) refresh(true);
}

pub fn record(outcome: Outcome, name: []const u8) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (active) |*session| screen.model.evidence(&session.Progress, outcome, name);
}

pub fn isActive() bool {
    return active != null;
}

pub fn checkpoint() void {
    refresh(false);
}

pub fn bootBegin() bool {
    const session = if (active) |*current| current else return false;
    const timer_port = timer.locate();
    session.RollbackView = .{ .Timer = timer_port, .Clock = screen.clock.start(if (timer_port) |port| timer.read(port) else 0) };
    return timer_port != null;
}

pub fn bootExpected(total: usize) void {
    const session = if (active) |*current| current else return;
    const view = if (session.RollbackView) |*current| current else return;
    if (screen.model.beginWork(&session.Progress, total)) repaintBoot(session, view);
}

pub fn bootPulse() void {
    const session = if (active) |*current| current else return;
    const view = if (session.RollbackView) |*current| current else return;
    const timer_port = view.Timer orelse return;
    if (screen.clock.sample(&view.Clock, timer.read(timer_port))) repaintBoot(session, view);
}

pub fn bootCheckpoint(verified: usize) void {
    const session = if (active) |*current| current else return;
    const view = if (session.RollbackView) |*current| current else return;
    if (!screen.model.checkpoint(&session.Progress, verified)) return;
    if (view.Timer) |timer_port| {
        _ = screen.clock.sample(&view.Clock, timer.read(timer_port));
    } else {
        view.Clock.Frame = (view.Clock.Frame + 1) % screen.strings.text.SPINNER.len;
    }
    repaintBoot(session, view);
}

fn repaintBoot(session: *Session, view: *types.Rollback) void {
    const percent = screen.model.percent(&session.Progress);
    const slots = screen.model.scaled(&session.Progress, screen.render.progressSlots(session.Layout.Progress.Width));
    const repaint_progress = percent != view.Percent or slots != view.FilledSlots;
    const text: screen.types.render.Text = .{ .Face = &session.Face, .Renderer = &renderer };
    if (screen.render.updateActive(&session.Surface, session.Layout, session.Pixels, text, &session.Progress, view.Clock.Frame, repaint_progress)) {
        view.Percent = percent;
        view.FilledSlots = slots;
    }
}

pub fn finish(outcome: Outcome) void {
    const flags = guard.acquire();
    const changed = if (active) |*session| finished: {
        if (!screen.model.finish(&session.Progress, outcome)) break :finished false;
        session.RollbackView = null;
        break :finished true;
    } else false;
    guard.release(flags);
    if (changed) refresh(true);
}

pub fn fail(name: []const u8) void {
    const flags = guard.acquire();
    const changed = if (active) |*session| screen.model.fail(&session.Progress, name) else false;
    guard.release(flags);
    if (changed and flags & control.RFLAGS_INTERRUPT_ENABLE != 0) refresh(true);
}

pub fn complete() void {
    const flags = guard.acquire();
    const changed = if (active) |*session| screen.model.endPhase(&session.Progress) else false;
    guard.release(flags);
    if (changed) refresh(true);
}

pub fn release() void {
    const flags = guard.acquire();
    const session = active;
    active = null;
    guard.release(flags);
    if (session) |current| pmm.free.range.freeRange(current.Physical, current.Pages);
}

fn refresh(force: bool) void {
    const flags = guard.acquire();
    const session = if (active) |*value| value else {
        guard.release(flags);
        return;
    };
    const ticks_per_frame = @max(1, screen.constants.frame.ANIMATION_MILLISECONDS * rate.TARGET_FREQUENCY / std.time.ms_per_s);
    const frame = @as(usize, @intCast((pit.getTicks() -| session.Started) / ticks_per_frame % screen.strings.text.SPINNER.len));
    if (session.Rendering or (!force and frame == session.LastFrame)) {
        guard.release(flags);
        return;
    }
    var snapshot = session.Progress;
    const stored = session.Rows[session.Layout.VisibleRows..];
    @memcpy(stored[0..snapshot.Count], snapshot.Rows[0..snapshot.Count]);
    snapshot.Rows = stored;
    session.LastFrame = frame;
    session.Rendering = true;
    guard.release(flags);
    _ = screen.render.update(&session.Surface, session.Layout, session.Pixels, .{ .Face = &session.Face, .Renderer = &renderer }, &snapshot, frame);
    const after = guard.acquire();
    session.Rendering = false;
    guard.release(after);
}
