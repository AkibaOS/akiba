//! Validate Entire RGB Rectangles Before Presenting Their Rows

const std = @import("std");

const format = @import("shared").display.constants.format;
const geometry = @import("shared").display.geometry.rectangle;
const invoke = @import("personaasm").invoke;
const limits = @import("shared").persona.constants.postman;
const pixels = @import("display").raster.row;

const Mode = @import("shared").display.types.mode.Mode;
const Operation = @import("shared").device.types.operation.Operation;
const Rectangle = @import("shared").display.types.rectangle.Rectangle;
const Row = @import("shared").display.types.row.Row;
const Status = @import("shared").persona.types.invocation.Status;

pub fn present(handle: u64, mode: Mode, payload: []const u8) bool {
    const header_bytes = @sizeOf(Rectangle);
    if (payload.len < header_bytes) return false;
    const box = std.mem.bytesToValue(Rectangle, payload[0..header_bytes]);
    if (!geometry.contains(mode, box)) return false;
    const length = geometry.inputBytes(box) orelse return false;
    if (length != payload.len - header_bytes) return false;
    var output: [limits.MAX_PAYLOAD_BYTES / @sizeOf(u32)]u32 = undefined;
    var offset: usize = header_bytes;
    for (0..box.Height) |line| {
        var column: u32 = 0;
        while (column < box.Width) {
            const count: u32 = @intCast(@min(output.len, box.Width - column));
            const bytes = count * format.RGB_BYTES;
            if (!pixels.pack(mode.Format, payload[offset..][0..bytes], output[0..count])) return false;
            const row: Row = .{ .X = box.X + column, .Y = box.Y + @as(u32, @intCast(line)), .Width = count, .Pixels = @intFromPtr(&output) };
            const result = invoke.call(.Device, @intFromEnum(Operation.SurfaceRow), handle, @intFromPtr(&row), 0);
            if (result.Status != @intFromEnum(Status.Success)) return false;
            offset += bytes;
            column += count;
        }
    }
    return true;
}
