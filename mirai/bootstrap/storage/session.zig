//! Identify The Boot Disk Inside A Scoped Device Session

const session = @import("mirai").device.ahci.session;
const transfer = @import("mirai").bootstrap.storage.transfer;

const Context = @import("mirai").bootstrap.types.storage.session.Context;
const Controller = @import("shared").ahci.types.discover.controller.Controller;
const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Match = @import("mirai").bootstrap.types.storage.session.Match;
const Slot = @import("mirai").device.types.ahci.slot.Slot;

pub fn withDisk(device: Controller, aperture: u64, port: u64, reclaimable: *bool, context: *anyopaque, use: Match) !bool {
    var request: Context = .{ .Argument = context, .Use = use };
    return session.withSlot(device, aperture, port, reclaimable, &request, attached);
}

fn attached(context: *anyopaque, slot: Slot) !bool {
    const request: *const Context = @ptrCast(@alignCast(context));
    var disk: Disk = .{ .Slot = slot, .Sectors = try transfer.identify(slot) };
    return request.Use(request.Argument, &disk);
}
