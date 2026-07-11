//! Kernel Entry

const root = @import("root");
const boot_params = @import("boot.zig");

const regions = root.boot.regions;
const boot_sequence = root.boot.sequence;
const framebuffer = root.drivers.framebuffer;
const asm_cpu = root.asm_ops.cpu;

pub const BootParams = boot_params.BootParams;

const error_color_rgb: u32 = 0xFF0000;
const error_color_bgr: u32 = 0x0000FF;

pub fn main(boot_params_ptr: *BootParams) noreturn {
    const framebuffer_info = boot_params_ptr.framebuffer;
    _ = framebuffer.initialize(
        framebuffer_info.base,
        framebuffer_info.width,
        framebuffer_info.height,
        framebuffer_info.stride,
    );

    if (!boot_params_ptr.is_valid()) {
        framebuffer.fill(switch (framebuffer_info.pixel_format) {
            .bgr => error_color_bgr,
            else => error_color_rgb,
        });
        asm_cpu.halt.halt_loop();
    }

    const memory_regions = regions.convert(boot_params_ptr.memory_map);

    const boot_info = boot_sequence.BootInfo{
        .memory_map = memory_regions.ptr,
        .memory_map_count = memory_regions.len,
        .framebuffer_address = framebuffer_info.base,
        .framebuffer_width = framebuffer_info.width,
        .framebuffer_height = framebuffer_info.height,
        .framebuffer_pitch = framebuffer_info.stride * 4,
        .framebuffer_bpp = 32,
        .kernel_physical_base = boot_params_ptr.kernel.physical_base,
        .kernel_physical_end = boot_params_ptr.kernel.physical_base + boot_params_ptr.kernel.size,
        .kernel_virtual_base = boot_params_ptr.kernel.virtual_base,
        .pml4_physical = boot_params_ptr.kernel.pml4_address,
        .rsdp_address = boot_params_ptr.acpi.rsdp_address,
        .boot_stack_top = boot_params_ptr.kernel.stack_top,
    };

    if (!boot_sequence.execute(&boot_info)) {
        boot_sequence.halt_on_failure();
    }

    asm_cpu.halt.halt_loop();
}
