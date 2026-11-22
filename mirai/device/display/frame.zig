//! Copy Validated Driver Rows To The Adopted Boot Framebuffer

const std = @import("std");

const binding = @import("mirai").device.binding;
const copy = @import("mirai").user.copy.transfer;
const geometry = @import("shared").display.geometry.rectangle;
const guard = @import("asm").interrupts.guard;
const instances = @import("mirai").device.instance.registry;
const limits = @import("mirai").user.constants.limits;
const locations = @import("mirai").device.constants.instance.limits;
const messages = @import("mirai").device.strings.instance.messages;
const postman = @import("mirai").postman;

const Framebuffer = @import("shared").boot.types.framebuffer.FramebufferInfo;
const Mode = @import("shared").display.types.mode.Mode;
const Row = @import("shared").display.types.operation.Row;
const Thread = @import("mirai").thread.types.thread.Thread;

var framebuffer: ?Framebuffer = null;

pub fn adopt(descriptor: Framebuffer) void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (framebuffer != null or !descriptor.isValid()) return;
    _ = instances.register(.Framebuffer, locations.FIRMWARE_SURFACE) orelse @panic(messages.REGISTRY_FULL);
    framebuffer = descriptor;
}

pub fn check(caller: *Thread) !void {
    try postman.validate.current(caller);
    if (binding.owner(.Display) != caller.Owner) return error.InvalidCaller;
}

pub fn mode() !Mode {
    const current = framebuffer orelse return error.NotInitialized;
    return describe(current);
}

pub fn present(caller: *Thread, row: Row) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    try check(caller);
    const current = framebuffer orelse return error.NotInitialized;
    if (row.Reserved != 0 or row.Width > limits.MAX_COPY_BYTES / @sizeOf(u32)) return error.InvalidArgument;
    const offset = geometry.rowOffset(describe(current), row.X, row.Y, row.Width, @intCast(current.Size / @sizeOf(u32))) orelse return error.InvalidArgument;
    var bytes: [limits.MAX_COPY_BYTES]u8 = undefined;
    const length = @as(usize, row.Width) * @sizeOf(u32);
    try copy.read(caller.Owner, bytes[0..length], row.Pixels);
    const destination: [*]volatile u32 = @ptrFromInt(current.Base);
    for (0..row.Width) |index| destination[offset + index] = std.mem.readInt(u32, bytes[index * @sizeOf(u32) ..][0..@sizeOf(u32)], .little);
}

fn describe(current: Framebuffer) Mode {
    return .{ .Width = current.Width, .Height = current.Height, .Stride = current.Stride, .Format = current.PixelFormat };
}
