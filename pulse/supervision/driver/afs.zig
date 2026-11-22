//! Start AFS And Verify A Real Stack Listing And Unit Read

const std = @import("std");

const afs = @import("shared").afs;
const elf = @import("shared").elf;
const install = @import("shared").location.strings.installed.paths;
const invoke = @import("personaasm").invoke;
const letters = @import("shared").afs.constants.service.postman;
const limits = @import("shared").persona.constants.postman;
const pulse = @import("pulse").supervision.inbox;

const Call = @import("shared").persona.types.call.Call;
const Entry = afs.types.read.list.Entry;
const Header = @import("shared").persona.types.letter.Header;
const Operation = @import("shared").pulse.types.boot.driver.Operation;
const Status = @import("shared").persona.types.invocation.Status;

pub fn start(ahci: u64) u64 {
    const launched = invoke.call(.BootstrapDriver, @intFromEnum(Operation.StartAfs), ahci, 0, 0);
    if (launched.Status != @intFromEnum(Status.Success)) pulse.stop(launched.Status);
    if (launched.Value == 0 or !verify(launched.Value)) pulse.stop(@intFromEnum(Status.InvalidReply));
    const confirmed = invoke.call(.BootstrapDriver, @intFromEnum(Operation.ConfirmAfs), launched.Value, 0, 0);
    if (confirmed.Status != @intFromEnum(Status.Success)) pulse.stop(confirmed.Status);
    return launched.Value;
}

fn verify(driver: u64) bool {
    if (!listed(driver)) return false;
    var size: [@sizeOf(u64)]u8 = undefined;
    if (!request(driver, letters.STAT, letters.SIZE, install.FLAT_AFS_PATH, 0, 0, &size)) return false;
    var bytes: [@sizeOf(elf.types.format.Elf64Header)]u8 = undefined;
    if (std.mem.readInt(u64, &size, .little) < bytes.len or !request(driver, letters.READ, letters.DATA, install.FLAT_AFS_PATH, 0, bytes.len, &bytes)) return false;
    const image = elf.read.header.read(&bytes) catch return false;
    return image.isExecutable() and image.isX8664();
}

fn listed(driver: u64) bool {
    var ordinal: u64 = 0;
    while (true) : (ordinal += 1) {
        var entry: Entry = undefined;
        if (!request(driver, letters.LIST, letters.ENTRY, install.SYSTEM_DRIVERS, ordinal, 0, std.mem.asBytes(&entry))) return false;
        if (entry.Kind == .Unit and entry.Length == install.FLAT_AFS_UNIT.len) {
            for (install.FLAT_AFS_UNIT, entry.Identity[0..entry.Length]) |expected, actual| {
                if (expected != actual) break;
            } else return true;
        }
        if (ordinal == std.math.maxInt(u64)) return false;
    }
}

fn request(driver: u64, operation: u64, expected: u64, path: []const u8, offset: u64, count: u64, output: []u8) bool {
    var buffer: [limits.MAX_PAYLOAD_BYTES]u8 = undefined;
    const input = afs.service.request.encode(&buffer, path, offset, count) orelse return false;
    var header: Header = undefined;
    const descriptor: Call = .{
        .Destination = driver,
        .Type = operation,
        .Request = @intFromPtr(input.ptr),
        .RequestLength = input.len,
        .Reply = @intFromPtr(output.ptr),
        .ReplyCapacity = output.len,
        .Metadata = @intFromPtr(&header),
    };
    const response = invoke.call(.Call, @intFromPtr(&descriptor), 0, 0, 0);
    return response.Status == @intFromEnum(Status.Success) and response.Value == output.len and
        header.Sender == driver and header.Type == expected and header.Length == output.len and header.ReplyTicket == 0;
}
