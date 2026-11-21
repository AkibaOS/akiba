//! Acquire The Chosen Block Device Transport Before Firmware Exit

const std = @import("std");

const efi = @import("hikari").efi;
const fields = @import("shared").boot.constants.device.path;
const path = @import("shared").boot.device.path;

const BootServices = efi.types.services.boot.BootServices;
const Handle = efi.types.base.Handle;
const Transport = @import("shared").boot.types.transport.Transport;

pub fn fromHandle(services: *BootServices, handle: Handle) Transport {
    var interface: ?*anyopaque = null;
    if (services.HandleProtocol(handle, &efi.constants.guids.DEVICE_LOCATION_PROTOCOL, &interface) != efi.constants.status.codes.SUCCESS)
        return .Unknown;
    const raw: [*]const u8 = @ptrCast(interface orelse return .Unknown);
    if (@intFromPtr(raw) > std.math.maxInt(usize) - fields.LIMIT) return .Unknown;
    return path.decode(raw[0..fields.LIMIT]);
}
