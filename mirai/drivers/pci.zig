//! PCI (Peripheral Component Interconnect) bus enumeration

const serial = @import("serial.zig");

pub const PCIDevice = struct {
    bus: u8,
    device: u8,
    function: u8,
    vendor_id: u16,
    device_id: u16,
    class_code: u8,
    subclass: u8,
    prog_if: u8,
    revision: u8,
    bar0: u32,
    bar1: u32,
    bar2: u32,
    bar3: u32,
    bar4: u32,
    bar5: u32,
    interrupt_line: u8,
    interrupt_pin: u8,
};

const PCI_CONFIG_ADDRESS: u16 = 0xCF8;
const PCI_CONFIG_DATA: u16 = 0xCFC;

const MAX_DEVICES = 64;
var devices: [MAX_DEVICES]PCIDevice = undefined;
var device_count: usize = 0;

fn outl(port: u16, value: u32) void {
    asm volatile ("outl %[value], %[port]"
        :
        : [value] "{eax}" (value),
          [port] "{dx}" (port),
    );
}

fn inl(port: u16) u32 {
    return asm volatile ("inl %[port], %[result]"
        : [result] "={eax}" (-> u32),
        : [port] "{dx}" (port),
    );
}

fn outw(port: u16, value: u16) void {
    asm volatile ("outw %[value], %[port]"
        :
        : [value] "{ax}" (value),
          [port] "{dx}" (port),
    );
}

fn inw(port: u16) u16 {
    return asm volatile ("inw %[port], %[result]"
        : [result] "={ax}" (-> u16),
        : [port] "{dx}" (port),
    );
}

fn pci_config_read_u32(bus: u8, device: u8, function: u8, offset: u8) u32 {
    const address: u32 = (@as(u32, 1) << 31) |
        (@as(u32, bus) << 16) |
        (@as(u32, device) << 11) |
        (@as(u32, function) << 8) |
        (@as(u32, offset) & 0xFC);

    outl(PCI_CONFIG_ADDRESS, address);
    return inl(PCI_CONFIG_DATA);
}

fn pci_config_read_u16(bus: u8, device: u8, function: u8, offset: u8) u16 {
    const value = pci_config_read_u32(bus, device, function, offset);
    const shift = @as(u5, @truncate((offset & 2) * 8));
    return @truncate((value >> shift) & 0xFFFF);
}

fn pci_config_read_u8(bus: u8, device: u8, function: u8, offset: u8) u8 {
    const value = pci_config_read_u32(bus, device, function, offset);
    const shift = @as(u5, @truncate((offset & 3) * 8));
    return @truncate((value >> shift) & 0xFF);
}

fn pci_config_write_u32(bus: u8, device: u8, function: u8, offset: u8, value: u32) void {
    const address: u32 = (@as(u32, 1) << 31) |
        (@as(u32, bus) << 16) |
        (@as(u32, device) << 11) |
        (@as(u32, function) << 8) |
        (@as(u32, offset) & 0xFC);

    outl(PCI_CONFIG_ADDRESS, address);
    outl(PCI_CONFIG_DATA, value);
}

fn pci_config_write_u16(bus: u8, device: u8, function: u8, offset: u8, value: u16) void {
    const old = pci_config_read_u32(bus, device, function, offset);
    const shift = @as(u5, @truncate((offset & 2) * 8));
    const mask = @as(u32, 0xFFFF) << shift;
    const new = (old & ~mask) | (@as(u32, value) << shift);
    pci_config_write_u32(bus, device, function, offset, new);
}

pub fn scan_bus() void {
    serial.print("Scanning PCI bus...\n");

    var bus: u16 = 0;
    while (bus < 256) : (bus += 1) {
        var device: u8 = 0;
        while (device < 32) : (device += 1) {
            var function: u8 = 0;
            while (function < 8) : (function += 1) {
                const vendor_id = pci_config_read_u16(@truncate(bus), device, function, 0x00);

                if (vendor_id == 0xFFFF) {
                    if (function == 0) break;
                    continue;
                }

                if (device_count >= MAX_DEVICES) {
                    serial.print("WARNING: Too many PCI devices, increase MAX_DEVICES\n");
                    return;
                }

                var dev = &devices[device_count];
                dev.bus = @truncate(bus);
                dev.device = device;
                dev.function = function;
                dev.vendor_id = vendor_id;
                dev.device_id = pci_config_read_u16(@truncate(bus), device, function, 0x02);
                dev.revision = pci_config_read_u8(@truncate(bus), device, function, 0x08);
                dev.prog_if = pci_config_read_u8(@truncate(bus), device, function, 0x09);
                dev.subclass = pci_config_read_u8(@truncate(bus), device, function, 0x0A);
                dev.class_code = pci_config_read_u8(@truncate(bus), device, function, 0x0B);
                dev.bar0 = pci_config_read_u32(@truncate(bus), device, function, 0x10);
                dev.bar1 = pci_config_read_u32(@truncate(bus), device, function, 0x14);
                dev.bar2 = pci_config_read_u32(@truncate(bus), device, function, 0x18);
                dev.bar3 = pci_config_read_u32(@truncate(bus), device, function, 0x1C);
                dev.bar4 = pci_config_read_u32(@truncate(bus), device, function, 0x20);
                dev.bar5 = pci_config_read_u32(@truncate(bus), device, function, 0x24);
                dev.interrupt_line = pci_config_read_u8(@truncate(bus), device, function, 0x3C);
                dev.interrupt_pin = pci_config_read_u8(@truncate(bus), device, function, 0x3D);

                device_count += 1;

                serial.print("  ");
                print_hex_u8(@truncate(bus));
                serial.print(":");
                print_hex_u8(device);
                serial.print(".");
                print_hex_u8(function);
                serial.print(" ");
                print_hex_u16(vendor_id);
                serial.print(":");
                print_hex_u16(dev.device_id);
                serial.print(" Class: ");
                print_hex_u8(dev.class_code);
                print_hex_u8(dev.subclass);
                serial.print("\n");

                if (function == 0) {
                    const header_type = pci_config_read_u8(@truncate(bus), device, function, 0x0E);
                    if ((header_type & 0x80) == 0) break;
                }
            }
        }
    }

    serial.print("Found ");
    print_hex_u32(@truncate(device_count));
    serial.print(" PCI devices\n");
}

pub fn find_device_by_class(class: u8, subclass: u8) ?*PCIDevice {
    var i: usize = 0;
    while (i < device_count) : (i += 1) {
        if (devices[i].class_code == class and devices[i].subclass == subclass) {
            return &devices[i];
        }
    }
    return null;
}

pub fn enable_bus_mastering(dev: *PCIDevice) void {
    const command = pci_config_read_u16(dev.bus, dev.device, dev.function, 0x04);
    pci_config_write_u16(dev.bus, dev.device, dev.function, 0x04, command | 0x04);
}

pub fn enable_memory_space(dev: *PCIDevice) void {
    const command = pci_config_read_u16(dev.bus, dev.device, dev.function, 0x04);
    pci_config_write_u16(dev.bus, dev.device, dev.function, 0x04, command | 0x02);
}

fn print_hex_u8(value: u8) void {
    const hex = "0123456789ABCDEF";
    const buf = [_]u8{ hex[value >> 4], hex[value & 0xF] };
    serial.print(&buf);
}

fn print_hex_u16(value: u16) void {
    print_hex_u8(@truncate(value >> 8));
    print_hex_u8(@truncate(value & 0xFF));
}

fn print_hex_u32(value: u32) void {
    print_hex_u16(@truncate(value >> 16));
    print_hex_u16(@truncate(value & 0xFFFF));
}

pub fn get_devices() []PCIDevice {
    return devices[0..device_count];
}
