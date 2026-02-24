//! Spawn invocation - Create new Kata from executable

const afs = @import("../../fs/afs/afs.zig");
const ahci = @import("../../drivers/ahci/ahci.zig");
const copy = @import("../../utils/mem/copy.zig");
const fs_limits = @import("../../common/limits/fs.zig");
const handler = @import("../handler.zig");
const hikari = @import("../../hikari/loader.zig");
const kata_limits = @import("../../common/limits/kata.zig");
const memory_limits = @import("../../common/limits/memory.zig");
const paging_const = @import("../../common/constants/paging.zig");
const pmm = @import("../../memory/pmm.zig");
const pool = @import("../../kata/pool.zig");
const result = @import("../../utils/types/result.zig");
const serial = @import("../../drivers/serial/serial.zig");
const slice = @import("../../utils/mem/slice.zig");

const HIGHER_HALF: u64 = 0xFFFF800000000000;

var afs_instance: ?*afs.AFS(ahci.BlockDevice) = null;

pub fn set_afs_instance(fs: *afs.AFS(ahci.BlockDevice)) void {
    afs_instance = fs;
}

fn check_ash_pd256() u64 {
    for (&pool.pool, 0..) |*k, i| {
        if (pool.used[i] and k.id == 3 and k.page_table != 0) {
            const pml4: [*]volatile u64 = @ptrFromInt(k.page_table + HIGHER_HALF);
            if ((pml4[0] & 1) == 0) return 0xDEAD0001;
            const pdpt: [*]volatile u64 = @ptrFromInt((pml4[0] & paging_const.PTE_MASK) + HIGHER_HALF);
            if ((pdpt[0] & 1) == 0) return 0xDEAD0002;
            const pd: [*]volatile u64 = @ptrFromInt((pdpt[0] & paging_const.PTE_MASK) + HIGHER_HALF);
            return pd[256];
        }
    }
    return 0xDEAD0000;
}

fn verify_kernel_mapping(phys: u64) bool {
    // Check if physical address is correctly mapped via higher half
    const virt = phys + HIGHER_HALF;

    // Read from that address and write back - if mapping is wrong, we'd write to wrong place
    const ptr: [*]volatile u64 = @ptrFromInt(virt);
    const val = ptr[0];
    _ = val;

    // Check kernel's CR3 mapping of this address
    const asm_memory = @import("../../asm/memory.zig");
    const kernel_cr3 = asm_memory.read_page_table_base() & ~@as(u64, 0xFFF);

    const pml4_idx = (virt >> 39) & 0x1FF;
    const pdpt_idx = (virt >> 30) & 0x1FF;
    const pd_idx = (virt >> 21) & 0x1FF;
    const pt_idx = (virt >> 12) & 0x1FF;

    const pml4: [*]volatile u64 = @ptrFromInt(kernel_cr3 + HIGHER_HALF);
    if ((pml4[pml4_idx] & 1) == 0) {
        serial.printf("VERIFY: pml4[{d}] not present for phys {x}\n", .{ pml4_idx, phys });
        return false;
    }

    const pdpt: [*]volatile u64 = @ptrFromInt((pml4[pml4_idx] & paging_const.PTE_MASK) + HIGHER_HALF);
    if ((pdpt[pdpt_idx] & 1) == 0) {
        serial.printf("VERIFY: pdpt[{d}] not present for phys {x}\n", .{ pdpt_idx, phys });
        return false;
    }

    const pd: [*]volatile u64 = @ptrFromInt((pdpt[pdpt_idx] & paging_const.PTE_MASK) + HIGHER_HALF);
    if ((pd[pd_idx] & 1) == 0) {
        serial.printf("VERIFY: pd[{d}] not present for phys {x}\n", .{ pd_idx, phys });
        return false;
    }

    const pt: [*]volatile u64 = @ptrFromInt((pd[pd_idx] & paging_const.PTE_MASK) + HIGHER_HALF);
    if ((pt[pt_idx] & 1) == 0) {
        serial.printf("VERIFY: pt[{d}] not present for phys {x}\n", .{ pt_idx, phys });
        return false;
    }

    const mapped_phys = pt[pt_idx] & paging_const.PTE_MASK;
    if (mapped_phys != phys) {
        serial.printf("VERIFY: phys {x} maps to {x} instead!\n", .{ phys, mapped_phys });
        return false;
    }

    return true;
}

pub fn invoke(ctx: *handler.InvocationContext) void {
    const fs = afs_instance orelse return result.set_error(ctx);

    const location_ptr = ctx.rdi;
    const location_len = ctx.rsi;
    const pv_ptr = ctx.rdx;
    const pc = ctx.r10;

    if (!memory_limits.is_valid_kata_pointer(location_ptr)) return result.set_error(ctx);
    if (location_len > fs_limits.MAX_LOCATION_LENGTH) return result.set_error(ctx);

    var location_buf: [fs_limits.MAX_LOCATION_LENGTH]u8 = undefined;
    copy.from_ptr(&location_buf, location_ptr, location_len);
    const location = location_buf[0..location_len];

    var params: [kata_limits.MAX_PARAMETERS][]const u8 = undefined;
    var param_count: usize = 1;
    params[0] = location;

    if (pc > 1 and pv_ptr != 0 and memory_limits.is_valid_kata_pointer(pv_ptr)) {
        const pv = slice.typed_ptr_const(u64, pv_ptr);

        var i: usize = 1;
        while (i < pc and param_count < kata_limits.MAX_PARAMETERS) : (i += 1) {
            const param_ptr = pv[i];
            if (!memory_limits.is_valid_kata_pointer(param_ptr)) break;

            const param_str = slice.null_term_ptr(param_ptr);
            var len: usize = 0;
            while (param_str[len] != 0 and len < kata_limits.MAX_LOCATION_LENGTH) : (len += 1) {}

            params[param_count] = param_str[0..len];
            param_count += 1;
        }
    }

    const pd256_before = check_ash_pd256();

    // Verify kernel can correctly access Ash's PD
    if (pmm.ash_pd_phys != 0) {
        if (!verify_kernel_mapping(pmm.ash_pd_phys)) {
            serial.printf("spawn: Kernel mapping of Ash's PD is WRONG!\n", .{});
        }
    }

    const kata_id = hikari.load_with_args(fs, location, params[0..param_count]) catch {
        return result.set_error(ctx);
    };

    const pd256_after = check_ash_pd256();

    // Track Ash's PD page (kata 3 is Ash)
    if (kata_id == 3) {
        if (pool.get(kata_id)) |kata| {
            if (kata.page_table != 0) {
                const pml4: [*]volatile u64 = @ptrFromInt(kata.page_table + HIGHER_HALF);
                if ((pml4[0] & 1) != 0) {
                    const pdpt: [*]volatile u64 = @ptrFromInt((pml4[0] & paging_const.PTE_MASK) + HIGHER_HALF);
                    if ((pdpt[0] & 1) != 0) {
                        const pd_phys = pdpt[0] & paging_const.PTE_MASK;
                        pmm.set_ash_pd(pd_phys);
                    }
                }
            }
        }
    } else if (pd256_after != pd256_before and pd256_before != 0xDEAD0000) {
        serial.printf("spawn: CORRUPTION during spawn of kata {d}! pd256: {x} -> {x}\n", .{ kata_id, pd256_before, pd256_after });
    }

    serial.printf("spawn: created kata {d}\n", .{kata_id});

    result.set_value(ctx, kata_id);
}
