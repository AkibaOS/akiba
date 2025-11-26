//! Runtime paging management

const serial = @import("../drivers/serial.zig");

extern fn setup_page_tables_64(phys_addr: u64) void;

pub fn map_framebuffer(fb_addr: u64) void {
    const aligned_addr = fb_addr & ~@as(u64, 0x1FFFFF);
    setup_page_tables_64(aligned_addr);
}
