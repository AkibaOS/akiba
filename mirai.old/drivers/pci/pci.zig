//! PCI bus enumeration

const int = @import("../../utils/types/int.zig");
const io = @import("../../asm/io.zig");
const pci_const = @import("../../common/constants/pci.zig");
const pci_limits = @import("../../common/limits/pci.zig");
const ports = @import("../../common/constants/ports.zig");
const types = @import("types.zig");

pub const Device = types.Device;

var devices: [pci_limits.MAX_DEVICES]Device = undefined;
var device_count: usize = 0;

fn config_address(bus: u8, device: u8, function: u8, offset: u8) u32 {
    return pci_const.CONFIG_ENABLE |
        (int.u32_of(bus) << pci_const.CONFIG_BUS_SHIFT) |
        (int.u32_of(device) << pci_const.CONFIG_DEVICE_SHIFT) |
        (int.u32_of(function) << pci_const.CONFIG_FUNCTION_SHIFT) |
        (int.u32_of(offset) & pci_const.CONFIG_OFFSET_MASK);
}

fn read_u32(bus: u8, device: u8, function: u8, offset: u8) u32 {
    io.out_long(ports.PCI_CONFIG_ADDRESS, config_address(bus, device, function, offset));
    return io.in_long(ports.PCI_CONFIG_DATA);
}

fn read_u16(bus: u8, device: u8, function: u8, offset: u8) u16 {
    const value = read_u32(bus, device, function, offset);
    const shift = int.u5_of((offset & 2) * 8);
    return int.u16_of(value >> shift);
}

fn read_u8(bus: u8, device: u8, function: u8, offset: u8) u8 {
    const value = read_u32(bus, device, function, offset);
    const shift = int.u5_of((offset & 3) * 8);
    return int.u8_of(value >> shift);
}

fn write_u32(bus: u8, device: u8, function: u8, offset: u8, value: u32) void {
    io.out_long(ports.PCI_CONFIG_ADDRESS, config_address(bus, device, function, offset));
    io.out_long(ports.PCI_CONFIG_DATA, value);
}

fn write_u16(bus: u8, device: u8, function: u8, offset: u8, value: u16) void {
    const old = read_u32(bus, device, function, offset);
    const shift = int.u5_of((offset & 2) * 8);
    const mask = int.u32_of(0xFFFF) << shift;
    const new = (old & ~mask) | (int.u32_of(value) << shift);
    write_u32(bus, device, function, offset, new);
}

pub fn scan_bus() void {
    var bus: u16 = 0;
    while (bus < pci_limits.MAX_BUS) : (bus += 1) {
        var device: u8 = 0;
        while (device < pci_limits.MAX_DEVICE) : (device += 1) {
            var function: u8 = 0;
            while (function < pci_limits.MAX_FUNCTION) : (function += 1) {
                const vendor = read_u16(int.u8_of(bus), device, function, pci_const.REG_VENDOR_ID);

                if (vendor == pci_const.VENDOR_INVALID) {
                    if (function == 0) break;
                    continue;
                }

                if (device_count >= pci_limits.MAX_DEVICES) return;

                var dev = &devices[device_count];
                dev.bus = int.u8_of(bus);
                dev.device = device;
                dev.function = function;
                dev.vendor_id = vendor;
                dev.device_id = read_u16(int.u8_of(bus), device, function, pci_const.REG_DEVICE_ID);
                dev.revision = read_u8(int.u8_of(bus), device, function, pci_const.REG_REVISION);
                dev.prog_if = read_u8(int.u8_of(bus), device, function, pci_const.REG_PROG_IF);
                dev.subclass = read_u8(int.u8_of(bus), device, function, pci_const.REG_SUBCLASS);
                dev.class_code = read_u8(int.u8_of(bus), device, function, pci_const.REG_CLASS_CODE);
                dev.bar0 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR0);
                dev.bar1 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR1);
                dev.bar2 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR2);
                dev.bar3 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR3);
                dev.bar4 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR4);
                dev.bar5 = read_u32(int.u8_of(bus), device, function, pci_const.REG_BAR5);
                dev.interrupt_line = read_u8(int.u8_of(bus), device, function, pci_const.REG_INTERRUPT_LINE);
                dev.interrupt_pin = read_u8(int.u8_of(bus), device, function, pci_const.REG_INTERRUPT_PIN);

                device_count += 1;

                if (function == 0) {
                    const header = read_u8(int.u8_of(bus), device, function, pci_const.REG_HEADER_TYPE);
                    if ((header & pci_const.HEADER_MULTIFUNCTION) == 0) break;
                }
            }
        }
    }
}

pub fn find_by_class(class: u8, subclass: u8) ?*Device {
    for (devices[0..device_count]) |*dev| {
        if (dev.class_code == class and dev.subclass == subclass) {
            return dev;
        }
    }
    return null;
}

pub fn enable_bus_mastering(dev: *Device) void {
    const cmd = read_u16(dev.bus, dev.device, dev.function, pci_const.REG_COMMAND);
    write_u16(dev.bus, dev.device, dev.function, pci_const.REG_COMMAND, cmd | pci_const.CMD_BUS_MASTER);
}

pub fn enable_memory_space(dev: *Device) void {
    const cmd = read_u16(dev.bus, dev.device, dev.function, pci_const.REG_COMMAND);
    write_u16(dev.bus, dev.device, dev.function, pci_const.REG_COMMAND, cmd | pci_const.CMD_MEMORY_SPACE);
}

pub fn get_devices() []Device {
    return devices[0..device_count];
}
