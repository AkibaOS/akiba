//! Mirai Kernel - Main Entry Point

const drivers = struct {
    const serial = @import("drivers/serial.zig");
    const ata = @import("drivers/ata.zig");
};

const boot = @import("boot/multiboot2.zig");
const afs = @import("fs/afs.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    drivers.serial.init();
    drivers.serial.print("\r\n=== AKIBA OS ===\r\n");
    drivers.serial.print("Drifting from abyss towards the infinite!\r\n\r\n");

    if (boot.parse_multiboot2(multiboot_info_addr)) |fb| {
        drivers.serial.print("Framebuffer: ");
        drivers.serial.print_hex(fb.width);
        drivers.serial.print("x");
        drivers.serial.print_hex(fb.height);
        drivers.serial.print("\r\n");
    }

    drivers.serial.print("\r\nInitializing AFS...\r\n");
    var device = drivers.ata.BlockDevice.init();

    var fs = afs.AFS.init(&device) catch |err| {
        drivers.serial.print("ERROR: AFS init failed: ");
        drivers.serial.print(@errorName(err));
        drivers.serial.print("\r\n");
        while (true) {
            asm volatile ("hlt");
        }
    };

    drivers.serial.print("AFS initialized!\r\n");

    _ = fs.list_directory(fs.root_cluster) catch {};

    drivers.serial.print("\r\nLooking for SYSTEM directory...\r\n");
    if (fs.find_file(fs.root_cluster, "SYSTEM")) |system_dir| {
        if ((system_dir.attributes & afs.ATTR_DIRECTORY) != 0) {
            const system_cluster = (@as(u32, system_dir.first_cluster_high) << 16) | @as(u32, system_dir.first_cluster_low);
            drivers.serial.print("Found SYSTEM at cluster ");
            drivers.serial.print_hex(system_cluster);
            drivers.serial.print("\r\n");

            _ = fs.list_directory(system_cluster) catch {};
        }
    } else {
        drivers.serial.print("SYSTEM directory not found\r\n");
    }

    drivers.serial.print("\r\n** Kernel ready! **\r\n");

    while (true) {
        asm volatile ("hlt");
    }
}
