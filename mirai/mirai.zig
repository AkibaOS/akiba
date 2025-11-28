const serial = @import("drivers/serial.zig");
const multiboot = @import("boot/multiboot2.zig");
const pmm = @import("memory/pmm.zig");
const paging = @import("memory/paging.zig");
const heap = @import("memory/heap.zig");
const idt = @import("interrupts/idt.zig");
const keyboard = @import("drivers/keyboard.zig");
const ata = @import("drivers/ata.zig");
const afs = @import("fs/afs.zig");
const font = @import("graphics/fonts/psf.zig");
const terminal = @import("terminal.zig");
const ash = @import("ash/ash.zig");

var terminal_ready = false;
var filesystem: ?*afs.AFS = null;

export fn mirai(multiboot_info_addr: u64) noreturn {
    serial.init();

    serial.print("\n");
    serial.print("═══════════════════════════════════\n");
    serial.print("      AKIBA OS - Full Boot\n");
    serial.print("═══════════════════════════════════\n");

    // Parse memory
    const memory_map = multiboot.parse_memory_map(multiboot_info_addr);
    const kernel_end: u64 = 0x500000;

    // Initialize memory management
    pmm.init(kernel_end, memory_map);
    paging.init();
    heap.init();

    // Initialize interrupts (before keyboard)
    idt.init();

    // Parse framebuffer EARLY
    const fb_info = multiboot.parse_framebuffer(multiboot_info_addr);

    // Initialize ATA and filesystem
    serial.print("\n=== Initializing Storage ===\n");
    var device = ata.BlockDevice.init();

    var fs = afs.AFS.init(&device) catch |err| {
        serial.print("ERROR: Failed to initialize AFS: ");
        serial.print(@errorName(err));
        serial.print("\n");

        keyboard.init();

        while (true) {
            asm volatile ("hlt");
        }
    };

    filesystem = &fs;
    serial.print("AFS mounted successfully!\n");

    // Load font BEFORE initializing terminal
    serial.print("\n=== Loading Font ===\n");
    var font_loaded = false;

    if (fs.find_file(fs.root_cluster, "SYSTEM")) |system_dir| {
        serial.print("Found /SYSTEM\n");
        const system_cluster = (@as(u32, system_dir.first_cluster_high) << 16) |
            @as(u32, system_dir.first_cluster_low);

        if (fs.find_file(system_cluster, "FONTS")) |fonts_dir| {
            serial.print("Found /SYSTEM/FONTS\n");
            const fonts_cluster = (@as(u32, fonts_dir.first_cluster_high) << 16) |
                @as(u32, fonts_dir.first_cluster_low);

            if (fs.find_file(fonts_cluster, "AKIBA.PSF")) |font_file| {
                serial.print("Found AKIBA.PSF (");
                serial.print_hex(font_file.file_size);
                serial.print(" bytes)\n");

                // Allocate buffer for font
                const font_buffer = heap.alloc(font_file.file_size) orelse {
                    serial.print("ERROR: Failed to allocate memory for font\n");
                    while (true) {
                        asm volatile ("hlt");
                    }
                };

                // Read font file
                const bytes_read = fs.read_file(font_file, font_buffer[0..font_file.file_size]) catch {
                    serial.print("ERROR: Failed to read font file\n");
                    heap.free(font_buffer, font_file.file_size);
                    while (true) {
                        asm volatile ("hlt");
                    }
                };

                serial.print("Read ");
                serial.print_hex(bytes_read);
                serial.print(" bytes\n");

                // Initialize font
                font.init(font_buffer[0..bytes_read]) catch {
                    serial.print("ERROR: Failed to parse font\n");
                    serial.print("Font might be corrupted or wrong format\n");
                    heap.free(font_buffer, font_file.file_size);
                };

                // Check if font loaded correctly
                serial.print("Font dimensions: ");
                serial.print_hex(font.get_width());
                serial.print("x");
                serial.print_hex(font.get_height());
                serial.print("\n");

                if (font.get_width() > 0 and font.get_height() > 0) {
                    font_loaded = true;
                    serial.print("Font loaded successfully!\n");
                } else {
                    serial.print("ERROR: Font loaded but dimensions are zero\n");
                }
            } else {
                serial.print("ERROR: AKIBA.PSF not found in /SYSTEM/FONTS\n");
            }
        } else {
            serial.print("ERROR: /SYSTEM/FONTS not found\n");
        }
    } else {
        serial.print("ERROR: /SYSTEM directory not found\n");
    }

    if (!font_loaded) {
        serial.print("WARNING: Continuing without font - display will be broken\n");
    }

    // NOW initialize graphics (font is already loaded)
    if (fb_info) |fb| {
        serial.print("\n=== Initializing Graphics ===\n");
        terminal.init(fb);
        terminal_ready = true;

        if (font_loaded) {
            terminal.print("\n");
            terminal.print("AKIBA OS\n");
            terminal.print("System Ready\n");
            terminal.print("\n");
        }
    } else {
        serial.print("WARNING: No framebuffer found\n");
    }

    // Initialize keyboard
    keyboard.init();

    // Initialize shell
    if (terminal_ready and font_loaded) {
        ash.init(&fs);
    }

    serial.print("\n** System Ready **\n");

    while (true) {
        asm volatile ("hlt");
    }
}

export fn on_key_typed(char: u8) void {
    if (terminal_ready) {
        ash.on_key_press(char);
    }
}
