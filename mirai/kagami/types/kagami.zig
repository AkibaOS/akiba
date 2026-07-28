//! Kagami Structure

const state = @import("mirai").kagami.state;

pub const Kagami = struct {
    PML4Physical: u64,
    ReferenceCount: u32,
    ResidentPages: u64,
    WiredPages: u64,
    TablePages: u64,
    Lock: bool,

    pub fn isKernel(self: *const Kagami) bool {
        const kernel_kagami = state.getKernelKagami();
        return self.PML4Physical == kernel_kagami.PML4Physical;
    }

    pub fn incrementReference(self: *Kagami) void {
        self.ReferenceCount += 1;
    }

    pub fn decrementReference(self: *Kagami) u32 {
        if (self.ReferenceCount > 0) {
            self.ReferenceCount -= 1;
        }
        return self.ReferenceCount;
    }

    pub fn addResident(self: *Kagami) void {
        self.ResidentPages += 1;
    }

    pub fn removeResident(self: *Kagami) void {
        if (self.ResidentPages > 0) {
            self.ResidentPages -= 1;
        }
    }

    pub fn addWired(self: *Kagami) void {
        self.WiredPages += 1;
    }

    pub fn removeWired(self: *Kagami) void {
        if (self.WiredPages > 0) {
            self.WiredPages -= 1;
        }
    }

    pub fn addTable(self: *Kagami) void {
        self.TablePages += 1;
    }

    pub fn removeTable(self: *Kagami) void {
        if (self.TablePages > 0) {
            self.TablePages -= 1;
        }
    }
};
