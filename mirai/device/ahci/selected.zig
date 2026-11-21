//! Execute A Transfer On The Exact Detached AHCI Port

const attachment = @import("mirai").device.ahci.attachment;
const discover = @import("shared").ahci.discover.pci;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").device.pci.configuration;
const physmap = @import("mirai").kagami.tables.physmap;
const registers = @import("mirai").device.ahci.registers;
const session = @import("mirai").device.ahci.session;
const transfer = @import("mirai").device.ahci.transfer;
const wire = @import("shared").ahci.constants.command.dma;

const AttachmentError = @import("mirai").device.errors.ahci.attachment.AttachmentError;
const Location = @import("shared").ahci.types.discover.selection.Location;
const Operation = @import("shared").ahci.types.command.operation.Operation;
const Request = @import("mirai").device.types.ahci.request.Request;
const Slot = @import("mirai").device.types.ahci.slot.Slot;
const TransferError = @import("mirai").device.errors.ahci.transfer.TransferError;

var quarantined = false;

pub fn execute(location: Location, operation: Operation, output: []u8) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (quarantined) return TransferError.AhciEngineDidNotStop;
    if (output.len != wire.SECTOR_BYTES) return TransferError.InvalidSectorBuffer;
    const device = (try discover.inspect(pci.source(), location.Address)) orelse return AttachmentError.BootDeviceChanged;
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var reclaimable = true;
    defer if (reclaimable) physmap.restoreDevicePage(alias) else {
        quarantined = true;
    };
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    const port = try attachment.exactPort(aperture, location.Port);
    if (!registers.detached(port)) return AttachmentError.AhciPortBusy;
    var request: Request = .{ .Operation = operation, .Output = output };
    _ = try session.withSlot(device, aperture, port, &reclaimable, &request, issue);
}

fn issue(context: *anyopaque, slot: Slot) !bool {
    const request: *Request = @ptrCast(@alignCast(context));
    try transfer.execute(slot, request.Operation, request.Output);
    return true;
}
