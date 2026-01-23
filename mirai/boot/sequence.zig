const afs = @import("../fs/afs.zig");
const ahci = @import("../drivers/ahci.zig");
const ata = @import("../drivers/ata.zig");
const crimson = @import("../crimson/panic.zig");
const font = @import("../graphics/fonts/psf.zig");
const gdt = @import("gdt.zig");
const gpt = @import("../fs/gpt.zig");
const hikari = @import("../hikari/loader.zig");
const heap = @import("../memory/heap.zig");
const idt = @import("../interrupts/idt.zig");
const invocations = @import("../invocations/handler.zig");
const kata = @import("../kata/kata.zig");
const keyboard = @import("../drivers/keyboard.zig");
const multiboot = @import("multiboot2.zig");
const paging = @import("../memory/paging.zig");
const pci = @import("../drivers/pci.zig");
const pmm = @import("../memory/pmm.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial.zig");
const shift = @import("../kata/shift.zig");
const terminal = @import("../terminal.zig");
const tss = @import("tss.zig");

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

fn boot_print(text: []const u8) void {
    buffer_or_print(text, COLOR_WHITE, false);
}

fn boot_print_color(text: []const u8, color: u32) void {
    buffer_or_print(text, color, true);
}

fn boot_ok() void {
    boot_print_color("[ OK ]\n", COLOR_OK);
}

fn boot_fail() void {
    boot_print_color("[ FAIL ]\n", COLOR_ERROR);
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

    boot_print("Initializing Kata management... ");
    kata.init();
    boot_ok();

    boot_print("Initializing Sensei scheduler... ");
    sensei.init();
    boot_ok();

    boot_print("Initializing context shifting... ");
    shift.init();
    boot_ok();

    boot_print("Setting up task state segment... ");
    tss.init();
    boot_ok();

    boot_print("Setting up global descriptor table... ");
    gdt.init();
    boot_ok();

    boot_print("Initializing Hikari loader... ");
    hikari.init();
    boot_ok();

    boot_print("Setting up interrupt descriptor table... ");
    idt.init();
    boot_ok();

    boot_print("Scanning PCI bus... ");
    pci.scan_bus();
    boot_ok();

    boot_print("Detecting storage controller... ");
    ahci.find_and_init() catch |err| {
        boot_fail();
        boot_print("ERROR: ");
        boot_print(@errorName(err));
        boot_print("\n");
        halt();
    };
    boot_ok();

    boot_print("Mounting Akiba File System... ");
    var device = ahci.BlockDevice.init();
    const afs_partition = gpt.find_afs_partition(&device) orelse {
        boot_fail();
        boot_print("ERROR: AFS partition not found\n");
        halt();
    };

    var fs = afs.AFS(ahci.BlockDevice).init(&device, afs_partition.start_lba) catch |err| {
        boot_fail();
        boot_print("ERROR: ");
        boot_print(@errorName(err));
        boot_print("\n");
        halt();
    };
    filesystem = &fs;
    boot_ok();

    boot_print("Initializing invocation handler... ");
    invocations.init(&fs);
    boot_ok();

    // Initialize terminal BEFORE loading Pulse
    boot_print("Loading font from filesystem... ");
    var font_buffer: [8192]u8 = undefined;
    const bytes_read = fs.read_file_by_path("/system/fonts/Akiba.psf", &font_buffer) catch |err| {
        boot_fail();
        boot_print("ERROR: ");
        boot_print(@errorName(err));
        boot_print("\n");
        halt();
    };

    font.init(font_buffer[0..bytes_read]) catch |err| {
        boot_fail();
        boot_print("ERROR: ");
        boot_print(@errorName(err));
        boot_print("\n");
        halt();
    };
    boot_ok();

    if (fb_info) |fb| {
        boot_print("Initializing framebuffer... ");
        terminal.init(fb);
        crimson.init(fb);
        multiboot.init_framebuffer(fb);
        terminal_ready = true;
        replay_messages();
        boot_ok();
    }

    boot_print("Initializing keyboard... ");
    keyboard.init();
    boot_ok();

    boot_print("Initializing Crimson error handler... ");
    boot_ok();

    boot_print_color("Boot sequence completed successfully!\n", COLOR_OK);
    delay(10);

    // Load Pulse
    boot_print("Initializing Pulse init system... ");
    const pulse_id = hikari.load_init_system(&fs) catch |err| {
        serial.print("Failed to load Pulse: ");
        serial.print(@errorName(err));
        serial.print("\n");
        crimson.collapse("Akiba's Pulse is missing. System is dying.", null);
    };
    _ = pulse_id;

    if (terminal_ready) {
        terminal.clear_screen();
        boot_print_color("Akiba OS\n", COLOR_MAGENTA);
        boot_print("Drifting from abyss towards infinity!\n\n");
    }

    // Start Pulse - this never returns
    sensei.schedule();

    // This should never be reached
    serial.print("ERROR: Returned from schedule()!\n");
}

fn halt() noreturn {
    while (true) {
        asm volatile ("hlt");
    }
}

fn delay(ms: u32) void {
    var i: u32 = 0;
    while (i < ms * 100000) : (i += 1) {
        asm volatile ("pause");
    }
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
