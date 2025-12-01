const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const ata = @import("../drivers/ata.zig");
const font = @import("../graphics/fonts/psf.zig");
const heap = @import("../memory/heap.zig");
const idt = @import("../interrupts/idt.zig");
const keyboard = @import("../drivers/keyboard.zig");
const multiboot = @import("../boot/multiboot2.zig");
const paging = @import("../memory/paging.zig");
const pci = @import("../drivers/pci.zig");
const pmm = @import("../memory/pmm.zig");
const serial = @import("../drivers/serial.zig");
const terminal = @import("../terminal.zig");

pub const COLOR_OK: u32 = 0x0000FF00;
pub const COLOR_INFO: u32 = 0x0000FFFF;
pub const COLOR_WARN: u32 = 0x00FFFF00;
pub const COLOR_ERROR: u32 = 0x00FF0000;
pub const COLOR_WHITE: u32 = 0x00FFFFFF;
pub const COLOR_MAGENTA: u32 = 0x00FF6B9D;

var terminal_ready: bool = false;
var filesystem: ?*afs.AFS(ahci.BlockDevice) = null;

const MessageType = enum { Normal, Color };

const Message = struct {
    text: [256]u8,
    len: usize,
    color: u32,
    msg_type: MessageType,
};

var message_buffer: [100]Message = undefined;
var message_count: usize = 0;

pub fn get_filesystem() *afs.AFS(ahci.BlockDevice) {
    return filesystem.?;
}

fn buffer_or_print(text: []const u8, color: u32, is_colored: bool) void {
    serial.print(text);

    if (terminal_ready) {
        if (is_colored) {
            terminal.print_color(text, color);
        } else {
            terminal.print(text);
        }
    } else {
        if (message_count >= message_buffer.len) return;

        var msg = &message_buffer[message_count];
        const copy_len = @min(text.len, 255);
        for (text[0..copy_len], 0..) |c, i| {
            msg.text[i] = c;
        }
        msg.len = copy_len;
        msg.msg_type = if (is_colored) .Color else .Normal;
        msg.color = color;
        message_count += 1;
    }
}

fn boot_print(text: []const u8) void {
    buffer_or_print(text, COLOR_WHITE, false);
}

fn boot_print_color(text: []const u8, color: u32) void {
    buffer_or_print(text, color, true);
}

fn replay_messages() void {
    for (message_buffer[0..message_count]) |msg| {
        if (msg.msg_type == .Color) {
            terminal.print_color(msg.text[0..msg.len], msg.color);
        } else {
            terminal.print(msg.text[0..msg.len]);
        }

        if (msg.len >= 5) {
            const is_ok_line = msg.text[0] == '[' and msg.text[2] == 'O' and msg.text[3] == 'K';
            if (is_ok_line) {
                delay(10);
            }
        }
    }
    message_count = 0;
}

fn boot_ok() void {
    boot_print_color("[ OK ]\n", COLOR_OK);
}

fn boot_fail() void {
    boot_print_color("[ FAIL ]\n", COLOR_ERROR);
}

fn delay(ms: u32) void {
    var i: u32 = 0;
    while (i < ms * 100000) : (i += 1) {
        asm volatile ("pause");
    }
}

pub fn run(multiboot_info_addr: u64) void {
    const fb_info = multiboot.parse_framebuffer(multiboot_info_addr);

    boot_print("Parsing memory map... ");
    const memory_map = multiboot.parse_memory_map(multiboot_info_addr);
    boot_ok();

    const kernel_end: u64 = 0x500000;

    boot_print("Initializing physical memory manager... ");
    pmm.init(kernel_end, memory_map);
    boot_ok();

    boot_print("Initializing paging... ");
    paging.init();
    boot_ok();

    boot_print("Initializing heap allocator... ");
    heap.init();
    boot_ok();

    boot_print("Setting up interrupt descriptor table... ");
    idt.init();
    boot_ok();

    boot_print("Scanning PCI bus... ");
    pci.scan_bus();
    boot_ok();

    boot_print("Detecting storage controller... ");

    const all_devices = pci.get_devices();
    var ahci_found = false;

    for (all_devices) |*dev| {
        if (dev.class_code == 0x01 and dev.subclass == 0x06) {
            ahci.init(dev) catch |err| {
                if (err == error.NoDriveFound) {
                    continue;
                }
                boot_fail();
                serial.print("ERROR: Failed to initialize AHCI: ");
                serial.print(@errorName(err));
                serial.print("\n");
                keyboard.init();
                while (true) {
                    asm volatile ("hlt");
                }
            };
            ahci_found = true;
            break;
        }
    }

    if (!ahci_found) {
        boot_fail();
        serial.print("ERROR: No AHCI controller with drive found\n");
        keyboard.init();
        while (true) {
            asm volatile ("hlt");
        }
    }
    boot_ok();

    boot_print("Mounting Akiba File System... ");
    var device = ahci.BlockDevice.init();
    var fs = afs.AFS(ahci.BlockDevice).init(&device) catch |err| {
        boot_fail();
        serial.print("ERROR: Failed to initialize AFS: ");
        serial.print(@errorName(err));
        serial.print("\n");

        keyboard.init();

        while (true) {
            asm volatile ("hlt");
        }
    };
    filesystem = &fs;
    boot_ok();

    boot_print("Loading font from filesystem... ");

    // Try to find SYSTEM directory
    serial.print("Looking for SYSTEM stack...\n");
    const system_entry = fs.find_file(fs.root_cluster, "SYSTEM     ") orelse {
        boot_fail();
        serial.print("ERROR: SYSTEM stack not found\n");
        return;
    };

    serial.print("Found SYSTEM, looking for FONTS...\n");
    const system_cluster = (@as(u32, system_entry.first_cluster_high) << 16) | @as(u32, system_entry.first_cluster_low);
    const fonts_entry = fs.find_file(system_cluster, "FONTS      ") orelse {
        boot_fail();
        serial.print("ERROR: FONTS stack not found\n");
        return;
    };

    serial.print("Found FONTS, looking for AKIBA.PSF...\n");
    const fonts_cluster = (@as(u32, fonts_entry.first_cluster_high) << 16) | @as(u32, fonts_entry.first_cluster_low);
    const font_entry = fs.find_file(fonts_cluster, "AKIBA   PSF") orelse {
        boot_fail();
        serial.print("ERROR: AKIBA.PSF not found\n");
        return;
    };

    serial.print("Reading font file...\n");
    var font_buffer: [8192]u8 = undefined;

    const bytes_read = fs.read_file(font_entry, &font_buffer) catch {
        boot_fail();
        serial.print("ERROR: Failed to read font file\n");
        return;
    };

    font.init(font_buffer[0..bytes_read]) catch |err| {
        boot_fail();
        serial.print("ERROR: Failed to parse PSF font: ");
        serial.print(@errorName(err));
        serial.print("\n");
        return;
    };

    boot_ok();

    if (fb_info) |fb| {
        terminal.init(fb);
        terminal_ready = true;

        replay_messages();

        boot_print("Initializing framebuffer... ");
        boot_ok();
    }

    boot_print("Initializing keyboard... ");
    keyboard.init();
    boot_ok();

    boot_print_color("Boot sequence completed successfully!\n", COLOR_OK);
    delay(10);
    boot_print("Starting Akiba shell (ash)... ");
    delay(100);

    if (terminal_ready) {
        terminal.clear_screen();
        boot_print_color("Akiba OS\n", COLOR_MAGENTA);
        boot_print("Drifting from abyss towards infinity!\n\n");
    }
}
