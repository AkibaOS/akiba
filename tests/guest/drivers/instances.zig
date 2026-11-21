//! Prove Boot Device Identity And Unpublished Assignment Lifetime

const hardware = @import("mirai").device.instance.registry;
const kata = @import("mirai").kata;
const labels = @import("tests").guest.strings.drivers.input;
const ports = @import("mirai").drivers.constants.keyboard.ports;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const keyboard = hardware.find(.Keyboard, ports.IRQ) orelse return error.InvalidFixture;
    const surface = hardware.find(.Framebuffer, 0) orelse return error.InvalidFixture;
    verify.require(keyboard != surface, labels.INSTANCES);

    const first = try kata.create.create();
    errdefer kata.destroy.destroy(first) catch {};
    const second = try kata.create.create();
    defer kata.destroy.destroy(second) catch {};
    const handle = try hardware.reserve(keyboard, first);
    verify.require(hardware.resolve(first, handle) == null, labels.PENDING_ASSIGNMENT);
    if (hardware.reserve(keyboard, second)) |_| {
        verify.require(false, labels.DEVICE_CONTENTION);
    } else |failure| {
        verify.require(failure == error.Busy, labels.DEVICE_CONTENTION);
    }
    const other = try hardware.reserve(surface, second);
    try kata.destroy.destroy(first);
    hardware.retire(second.ID);
    const replacement = try hardware.reserve(keyboard, second);
    verify.require(handle != replacement and other != replacement and hardware.resolve(second, handle) == null, labels.REBOUND_ASSIGNMENT);
}
