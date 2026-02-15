//! Global Descriptor Table

const cpu = @import("../../asm/cpu.zig");
const gdt_const = @import("../../common/constants/gdt.zig");
const io = @import("../../asm/io.zig");
const ports = @import("../../common/constants/ports.zig");
const serial = @import("../../drivers/serial/serial.zig");
const tss = @import("../tss/tss.zig");
const types = @import("types.zig");

pub const KERNEL_CODE = gdt_const.KERNEL_CODE;
pub const KERNEL_DATA = gdt_const.KERNEL_DATA;
pub const USER_DATA = gdt_const.USER_DATA;
pub const USER_CODE = gdt_const.USER_CODE;
pub const TSS_SEGMENT = gdt_const.TSS_SEGMENT;

var gdt: [8]u64 align(16) = undefined;
var gdt_ptr: types.Pointer = undefined;

pub fn init() void {
    gdt[0] = 0;
    gdt[1] = create_code_descriptor(0, true);
    gdt[2] = create_data_descriptor(0);
    gdt[3] = create_data_descriptor(3);
    gdt[4] = create_code_descriptor(3, true);

    create_tss_descriptor(tss.get_address(), tss.get_size());

    gdt_ptr = types.Pointer{
        .limit = @sizeOf(@TypeOf(gdt)) - 1,
        .base = @intFromPtr(&gdt),
    };

    cpu.load_global_descriptor_table(@intFromPtr(&gdt_ptr));
    cpu.reload_segment_registers(KERNEL_DATA);
    cpu.reload_code_segment(KERNEL_CODE);
    cpu.load_task_register(TSS_SEGMENT);

    io.out_byte(ports.PIC1_DATA, 0xFF);
    io.out_byte(ports.PIC2_DATA, 0xFF);

    serial.printf("GDT: code={x} data={x} ucode={x} udata={x} tss={x}\n", .{
        KERNEL_CODE, KERNEL_DATA, USER_CODE, USER_DATA, TSS_SEGMENT,
    });
}

fn create_code_descriptor(dpl: u8, long_mode: bool) u64 {
    var desc: u64 = 0;

    desc |= 0xFFFF;
    desc |= (@as(u64, 0xF) << 48);

    var access: u8 = 0;
    access |= (1 << 0);
    access |= (1 << 1);
    access |= (1 << 3);
    access |= (1 << 4);
    access |= (@as(u8, dpl & 0x3) << 5);
    access |= (1 << 7);
    desc |= (@as(u64, access) << 40);

    var flags: u8 = 0;
    flags |= (1 << 3);
    if (long_mode) {
        flags |= (1 << 1);
    } else {
        flags |= (1 << 2);
    }
    desc |= (@as(u64, flags) << 52);

    return desc;
}

fn create_data_descriptor(dpl: u8) u64 {
    var desc: u64 = 0;

    desc |= 0xFFFF;
    desc |= (@as(u64, 0xF) << 48);

    var access: u8 = 0;
    access |= (1 << 0);
    access |= (1 << 1);
    access |= (1 << 4);
    access |= (@as(u8, dpl & 0x3) << 5);
    access |= (1 << 7);
    desc |= (@as(u64, access) << 40);

    var flags: u8 = 0;
    flags |= (1 << 3);
    flags |= (1 << 2);
    desc |= (@as(u64, flags) << 52);

    return desc;
}

fn create_tss_descriptor(base: u64, limit: u64) void {
    var desc_low: u64 = 0;

    desc_low |= (limit & 0xFFFF);
    desc_low |= ((base & 0xFFFF) << 16);
    desc_low |= ((base & 0xFF0000) >> 16) << 32;
    desc_low |= (@as(u64, 0x89) << 40);
    desc_low |= (((limit >> 16) & 0xF) << 48);
    desc_low |= (((base & 0xFF000000) >> 24) << 56);

    gdt[5] = desc_low;
    gdt[6] = (base >> 32) & 0xFFFFFFFF;
}
