//! Hikari - Program loader

const afs = @import("../fs/afs/afs.zig");
const ahci = @import("../drivers/ahci/ahci.zig");
const elf = @import("elf/elf.zig");
const elf_const = @import("../common/constants/elf.zig");
const format = @import("format/format.zig");
const gdt = @import("../boot/gdt/gdt.zig");
const heap = @import("../memory/heap.zig");
const kata_limits = @import("../common/limits/kata.zig");
const kata_memory = @import("../kata/memory.zig");
const kata_mod = @import("../kata/kata.zig");
const memory_const = @import("../common/constants/memory.zig");
const multiboot = @import("../boot/multiboot/multiboot.zig");
const paging = @import("../memory/paging.zig");
const sensei = @import("../kata/sensei.zig");
const serial = @import("../drivers/serial/serial.zig");
const system = @import("../system/system.zig");

const INIT_PATH = "/system/akiba/pulse.akibainit";
const RFLAGS_DEFAULT: u64 = 0x3202;

pub fn init(fs: *afs.AFS(ahci.BlockDevice)) !u32 {
    const init_size = fs.get_unit_size(INIT_PATH) catch |err| {
        serial.print("FATAL: Cannot find init at ");
        serial.print(INIT_PATH);
        serial.print("\n");
        return err;
    };

    if (init_size == 0) {
        serial.print("FATAL: Init is empty\n");
        return error.EmptyFile;
    }

    var args: [1][]const u8 = .{INIT_PATH};
    return load_with_args(fs, INIT_PATH, &args);
}

pub fn load(fs: *afs.AFS(ahci.BlockDevice), path: []const u8) !u32 {
    var args: [1][]const u8 = .{path};
    return load_with_args(fs, path, &args);
}

pub fn load_with_args(
    fs: *afs.AFS(ahci.BlockDevice),
    path: []const u8,
    args: []const []const u8,
) !u32 {
    if (path.len == 0 or path.len > system.limits.MAX_PATH_LENGTH) {
        return error.InvalidPath;
    }

    const file_size = try fs.get_unit_size(path);

    if (file_size == 0) return error.EmptyFile;
    if (file_size > system.limits.MAX_FILE_SIZE) return error.FileTooLarge;

    const buffer_ptr = heap.alloc(@intCast(file_size)) orelse return error.OutOfMemory;
    defer heap.free(buffer_ptr, @intCast(file_size));
    const buffer = buffer_ptr[0..@intCast(file_size)];

    const bytes_read = try fs.view_unit_at(path, buffer);

    if (bytes_read != file_size) {
        return error.IncompleteRead;
    }

    const akiba_data = try format.parse(buffer[0..bytes_read]);
    const elf_info = try elf.parse(akiba_data.elf_data);

    const kata = try kata_mod.create_kata();
    errdefer kata_mod.dissolve_kata(kata.id);

    if (sensei.get_current_kata()) |parent| {
        kata.parent_id = parent.id;

        for (0..parent.current_location_len) |i| {
            kata.current_location[i] = parent.current_location[i];
        }
        kata.current_location_len = parent.current_location_len;
        kata.current_cluster = parent.current_cluster;
    }

    const fb_info = multiboot.get_framebuffer();
    const fb_phys = if (fb_info) |fb| fb.addr else 0;
    const fb_size = if (fb_info) |fb| fb.height * fb.pitch else 0;
    try kata_memory.setup_kata_memory(kata, fb_phys, fb_size);

    for (elf_info.program_headers) |phdr| {
        if (phdr.type == elf_const.PT_LOAD) {
            try kata_memory.load_segment(
                kata,
                phdr.vaddr,
                akiba_data.elf_data,
                phdr.offset,
                phdr.filesz,
                phdr.memsz,
                phdr.flags,
            );
        }
    }

    const adjusted_stack = try setup_stack_args(kata, args);
    setup_context(kata, elf_info.entry_point, adjusted_stack);

    sensei.enqueue_kata(kata);

    return kata.id;
}

fn setup_stack_args(kata: *kata_mod.Kata, args: []const []const u8) !u64 {
    var stack_top = kata.user_stack_top;
    const pc: u64 = args.len;

    var string_addrs: [kata_limits.MAX_ARGS]u64 = undefined;

    for (args, 0..) |arg, i| {
        const str_len = arg.len + 1;
        stack_top -= str_len;
        stack_top &= ~@as(u64, 0x7);

        string_addrs[i] = stack_top;

        const phys_addr = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
        const dest = @as([*]u8, @ptrFromInt(phys_addr + memory_const.HIGHER_HALF_START));

        for (arg, 0..) |c, j| {
            dest[j] = c;
        }
        dest[arg.len] = 0;
    }

    const pv_size = pc * 8;
    stack_top -= pv_size;
    stack_top &= ~@as(u64, 0x7);

    const pv_addr = stack_top;

    for (0..pc) |i| {
        const ptr_phys = paging.virt_to_phys(kata.page_table, pv_addr + i * 8) orelse return error.StackNotMapped;
        const ptr_dest = @as(*u64, @ptrFromInt(ptr_phys + memory_const.HIGHER_HALF_START));
        ptr_dest.* = string_addrs[i];
    }

    stack_top &= ~@as(u64, 0xF);

    stack_top -= 8;
    const pv_ptr_phys = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
    @as(*u64, @ptrFromInt(pv_ptr_phys + memory_const.HIGHER_HALF_START)).* = pv_addr;

    stack_top -= 8;
    const pc_phys = paging.virt_to_phys(kata.page_table, stack_top) orelse return error.StackNotMapped;
    @as(*u64, @ptrFromInt(pc_phys + memory_const.HIGHER_HALF_START)).* = pc;

    return stack_top;
}

fn setup_context(kata: *kata_mod.Kata, entry_point: u64, stack_pointer: u64) void {
    kata.context.rip = entry_point;
    kata.context.rsp = stack_pointer;
    kata.context.rflags = RFLAGS_DEFAULT;
    kata.context.cs = gdt.USER_CODE | 3;
    kata.context.ss = gdt.USER_DATA | 3;

    kata.context.rax = 0;
    kata.context.rbx = 0;
    kata.context.rcx = 0;
    kata.context.rdx = 0;
    kata.context.rsi = 0;
    kata.context.rdi = 0;
    kata.context.rbp = 0;
    kata.context.r8 = 0;
    kata.context.r9 = 0;
    kata.context.r10 = 0;
    kata.context.r11 = 0;
    kata.context.r12 = 0;
    kata.context.r13 = 0;
    kata.context.r14 = 0;
    kata.context.r15 = 0;
}
