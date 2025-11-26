//! Mirai Kernel - Main Entry Point

const drivers = struct {
    const serial = @import("drivers/serial.zig");
    const ata = @import("drivers/ata.zig");
};

const boot = @import("boot/multiboot2.zig");
const afs = @import("fs/afs.zig");
const font = @import("graphics/font.zig");
const idt = @import("arch/idt.zig");
const paging = @import("arch/paging.zig");

export fn mirai(multiboot_info_addr: u64) noreturn {
    drivers.serial.init();
    drivers.serial.print("\r\n=== AKIBA OS ===\r\n");
    drivers.serial.print("Drifting from abyss towards the infinite!\r\n\r\n");

    idt.init();

    const fb_info = boot.parse_multiboot2(multiboot_info_addr);

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

    if (fs.find_file(fs.root_cluster, "SYSTEM")) |system_dir| {
        const system_cluster = (@as(u32, system_dir.first_cluster_high) << 16) | @as(u32, system_dir.first_cluster_low);

        if (fs.find_file(system_cluster, "FONTS")) |fonts_dir| {
            const fonts_cluster = (@as(u32, fonts_dir.first_cluster_high) << 16) | @as(u32, fonts_dir.first_cluster_low);

            if (fs.find_file(fonts_cluster, "DEFAULT.PSF")) |font_file| {
                var font_buffer: [32768]u8 = undefined;
                _ = fs.read_file(font_file, &font_buffer) catch {};
                _ = font.init(font_buffer[0..font_file.file_size]) catch {};
                drivers.serial.print("Font loaded!\r\n");
            }
        }
    }

    if (fb_info) |fb| {
        paging.map_framebuffer(fb.addr);
        font.render_text("Akiba OS", 10, 10, fb, 0x00FF6B9D);
        font.render_text("Drifting from abyss towards the infinite!", 10, 30, fb, 0x00FFFFFF);
        drivers.serial.print("Graphics initialized!\r\n");
    }

    drivers.serial.print("\r\n** Akiba OS Ready **\r\n");

    while (true) {
        asm volatile ("hlt");
    }
}
