//! Q35 Physical Keyboard Input Without The UART Console Splitter

const std = @import("std");

const efi = @import("hikari").efi;
const limits = @import("menu").constants.limits;

const BootServices = efi.types.services.boot.BootServices;
const Handle = efi.types.base.Handle;
const Input = efi.types.protocols.input.SimpleTextInputProtocol;
const guids = efi.constants.guids;
const status = efi.constants.status;

pub fn locate(services: *BootServices) !*Input {
    var count: usize = 0;
    var handles: ?[*]Handle = null;
    if (services.LocateHandleBuffer(.ByProtocol, &guids.SIMPLE_TEXT_INPUT_PROTOCOL, null, &count, @ptrCast(&handles)) != status.SUCCESS) return error.MenuInputMissing;
    var pool: efi.types.buffer.PoolClaim = .{};
    const bytes = std.math.mul(usize, count, @sizeOf(Handle)) catch return error.InvalidMenuInputHandles;
    const raw: ?[*]align(8) u8 = if (handles) |list| @ptrCast(list) else null;
    if (!efi.buffer.recordPool(&pool, raw, bytes)) return error.InvalidMenuInputHandles;
    const input = find(services, handles.?[0..count]);
    if (!efi.buffer.releasePool(services, &pool)) return error.MenuInputHandlesReleaseFailed;
    return input;
}

fn find(services: *BootServices, handles: []const Handle) !*Input {
    var input: ?*Input = null;
    for (handles) |handle| {
        var path: ?*anyopaque = null;
        if (services.HandleProtocol(handle, &guids.DEVICE_LOCATION_PROTOCOL, &path) != status.SUCCESS) continue;
        if (!keyboardPath(@ptrCast(path orelse continue))) continue;
        var protocol: ?*anyopaque = null;
        if (services.HandleProtocol(handle, &guids.SIMPLE_TEXT_INPUT_PROTOCOL, &protocol) != status.SUCCESS) continue;
        if (input != null) return error.AmbiguousMenuKeyboard;
        input = @ptrCast(@alignCast(protocol orelse continue));
    }
    return input orelse error.MenuKeyboardMissing;
}

fn keyboardPath(path: [*]const u8) bool {
    var offset: usize = 0;
    var found = false;
    while (offset <= limits.DEVICE_PATH_LIMIT - limits.DEVICE_PATH_HEADER) {
        const node = path + offset;
        const size = std.mem.readInt(u16, node[2..4], .little);
        if (size < limits.DEVICE_PATH_HEADER or size > limits.DEVICE_PATH_LIMIT - offset) return false;
        if (node[0] == limits.END_DEVICE_PATH) return found and node[1] == limits.END_ENTIRE_PATH and size == limits.DEVICE_PATH_HEADER;
        if (node[0] == limits.ACPI_DEVICE_PATH and node[1] == limits.ACPI_HID_SUBTYPE and size == limits.ACPI_HID_BYTES and
            std.mem.readInt(u32, node[4..8], .little) == limits.PS2_KEYBOARD_HID) found = true;
        offset += size;
    }
    return false;
}
