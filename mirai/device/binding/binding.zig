//! Resolve Legacy Device Roles Against The Instance Registry

const instances = @import("mirai").device.instance.registry;
const locations = @import("mirai").device.constants.instance;
const ports = @import("mirai").drivers.constants.keyboard.ports;

const Kata = @import("mirai").kata.types.kata.Kata;
const Role = @import("shared").launch.types.device.Role;

pub fn find(role: Role) ?u64 {
    return switch (role) {
        .Keyboard => instances.find(.Keyboard, ports.IRQ),
        .Display => instances.find(.Framebuffer, locations.FIRMWARE_SURFACE),
    };
}

pub fn owner(role: Role) ?*Kata {
    return instances.assignedOwner(find(role) orelse return null);
}
