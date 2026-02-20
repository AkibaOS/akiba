//! Boot sequence

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const boot_limits = @import("../../common/limits/boot.zig");
const colors = @import("../../common/constants/colors.zig");
const cpu = @import("../../asm/cpu.zig");
const crimson = @import("../../crimson/crimson.zig");
const font = @import("../../graphics/fonts/psf.zig");
const gdt = @import("../gdt/gdt.zig");
const gpt = @import("../../fs/gpt/gpt.zig");
const heap = @import("../../memory/heap.zig");
const hikari = @import("../../hikari/loader.zig");
const idt = @import("../../interrupts/idt.zig");
const invocations = @import("../../invocations/handler.zig");
const kata = @import("../../kata/kata.zig");
const keyboard = @import("../../drivers/keyboard/keyboard.zig");
const message = @import("message.zig");
const multiboot = @import("../multiboot/multiboot.zig");
const pci = @import("../../drivers/pci/pci.zig");
const pit = @import("../../drivers/pit/pit.zig");
const pmm = @import("../../memory/pmm.zig");
const sensei = @import("../../kata/sensei/sensei.zig");
const serial = @import("../../drivers/serial/serial.zig");
const system = @import("../../system/system.zig");
const terminal = @import("../../graphics/terminal/terminal.zig");
const tss = @import("../tss/tss.zig");

var filesystem: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn get_filesystem() *afs.AFS(ahci.BlockDevice) {
    return filesystem.?;
}

pub fn run(multiboot_addr: u64) void {
    const fb_info = multiboot.parse_framebuffer(multiboot_addr);

    step("Parsing memory map");
    const memory_map = multiboot.parse_memory_map(multiboot_addr);
    ok();

    step("Initializing physical memory");
    pmm.init(system.constants.KERNEL_END(), memory_map);
    ok();

    step("Initializing heap");
    heap.init();
    ok();

    step("Initializing kata management");
    kata.init();
    ok();

    step("Setting up TSS");
    tss.init();
    ok();

    step("Setting up GDT");
    gdt.init();
    ok();

    step("Setting up IDT");
    idt.init();
    ok();

    step("Setting up PIT");
    pit.init();
    ok();

    step("Scanning PCI bus");
    pci.scan_bus();
    ok();

    step("Detecting storage controller");
    ahci.find_and_init() catch |err| {
        fail();
        print_error(err);
        halt();
    };
    ok();

    step("Mounting AFS");
    var device = ahci.BlockDevice.init();
    const partition = gpt.find_afs_partition(&device) orelse {
        fail();
        message.print("AFS partition not found\n");
        halt();
    };

    var fs = afs.AFS(ahci.BlockDevice).init(&device, partition.start_lba) catch |err| {
        fail();
        print_error(err);
        halt();
    };
    filesystem = &fs;
    ok();

    step("Initializing invocations");
    invocations.init(&fs);
    ok();

    step("Loading font");
    var font_buffer: [boot_limits.FONT_BUFFER_SIZE]u8 = undefined;
    const bytes_read = fs.view_unit_at("/system/fonts/akiba.psf", &font_buffer) catch |err| {
        fail();
        print_error(err);
        halt();
    };

    font.init(font_buffer[0..bytes_read]) catch |err| {
        fail();
        print_error(err);
        halt();
    };
    ok();

    if (fb_info) |fb| {
        step("Initializing framebuffer");
        terminal.init(fb);
        crimson.init(fb);
        multiboot.init_framebuffer(fb);
        message.set_terminal(terminal.print, terminal.print_color);
        ok();
    }

    step("Initializing keyboard");
    keyboard.init();
    ok();

    message.print_color("Boot complete!\n", colors.GREEN);

    step("Loading Pulse");
    _ = hikari.init(&fs) catch |err| {
        serial.printf("Failed to load Pulse: {s}\n", .{@errorName(err)});
        crimson.collapse("Akiba's Pulse is missing. System is dying.", null);
    };
    ok();

    if (message.is_ready()) {
        terminal.clear_screen();
        message.print_color("Akiba OS\n", colors.AKIBA_PINK);
        message.print("Drifting from abyss towards the infinity!\n\n");
    }

    sensei.schedule();

    serial.print("ERROR: Returned from schedule!\n");
    halt();
}

fn step(name: []const u8) void {
    message.print(name);
    message.print("... ");
}

fn ok() void {
    message.print_color("[ OK ]\n", colors.GREEN);
}

fn fail() void {
    message.print_color("[ FAIL ]\n", colors.RED);
}

fn print_error(err: anyerror) void {
    message.print("ERROR: ");
    message.print(@errorName(err));
    message.print("\n");
}

fn halt() noreturn {
    while (true) {
        cpu.halt_processor();
    }
}
