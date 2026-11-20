//! Byte Array Block Callback Fixtures

const std = @import("std");

const block = @import("shared").afs.types.block;
const constants = @import("tests").fast.constants.storage;
const errors = @import("shared").afs.errors.block;
const fixtures = @import("tests").fast.types.storage;

pub fn create() fixtures.ByteDevice {
    var device = fixtures.ByteDevice{};
    for (constants.CELL_VALUES, 0..) |value, cell| {
        @memset(device.Bytes[cell * constants.CELL_SIZE ..][0..constants.CELL_SIZE], value);
    }
    return device;
}

pub fn createReader(device: *fixtures.ByteDevice) block.BlockReader {
    return .{
        .Context = device,
        .ReadFn = readCell,
        .CellSize = constants.CELL_SIZE,
        .TotalCells = constants.TOTAL_CELLS,
    };
}

pub fn createWriter(device: *fixtures.ByteDevice) block.BlockWriter {
    return .{
        .Context = device,
        .WriteFn = writeCell,
        .CellSize = constants.CELL_SIZE,
        .TotalCells = constants.TOTAL_CELLS,
    };
}

fn readCell(context: *anyopaque, cell: u64, buffer: []u8) errors.BlockError!void {
    const device: *fixtures.ByteDevice = @ptrCast(@alignCast(context));
    device.Reads[device.ReadCount] = .{ .Cell = cell, .Length = buffer.len };
    device.ReadCount += 1;
    if (device.FailureCell == cell) {
        device.FailureCell = null;
        return errors.BlockError.DeviceError;
    }
    const offset: usize = @intCast(cell * constants.CELL_SIZE);
    std.mem.copyForwards(u8, buffer, device.Bytes[offset..][0..buffer.len]);
}

fn writeCell(context: *anyopaque, cell: u64, data: []const u8) errors.BlockError!void {
    const device: *fixtures.ByteDevice = @ptrCast(@alignCast(context));
    device.Writes[device.WriteCount] = .{ .Cell = cell, .Length = data.len };
    device.WriteCount += 1;
    if (device.FailureCell == cell) {
        device.FailureCell = null;
        return errors.BlockError.DeviceError;
    }
    const offset: usize = @intCast(cell * constants.CELL_SIZE);
    std.mem.copyForwards(u8, device.Bytes[offset..][0..data.len], data);
}
