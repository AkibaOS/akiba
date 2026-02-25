//! Kagami Structure

pub const Kagami = struct {
    pml4_physical: u64,
    reference_count: u32,
    resident_pages: u64,
    wired_pages: u64,
    table_pages: u64,
    lock: bool,

    pub fn is_kernel(self: *const Kagami) bool {
        const kernel_kagami = @import("../state.zig").get_kernel_kagami();
        return self.pml4_physical == kernel_kagami.pml4_physical;
    }

    pub fn increment_reference(self: *Kagami) void {
        self.reference_count += 1;
    }

    pub fn decrement_reference(self: *Kagami) u32 {
        if (self.reference_count > 0) {
            self.reference_count -= 1;
        }
        return self.reference_count;
    }

    pub fn add_resident(self: *Kagami) void {
        self.resident_pages += 1;
    }

    pub fn remove_resident(self: *Kagami) void {
        if (self.resident_pages > 0) {
            self.resident_pages -= 1;
        }
    }

    pub fn add_wired(self: *Kagami) void {
        self.wired_pages += 1;
    }

    pub fn remove_wired(self: *Kagami) void {
        if (self.wired_pages > 0) {
            self.wired_pages -= 1;
        }
    }

    pub fn add_table(self: *Kagami) void {
        self.table_pages += 1;
    }

    pub fn remove_table(self: *Kagami) void {
        if (self.table_pages > 0) {
            self.table_pages -= 1;
        }
    }
};
