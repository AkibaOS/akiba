//! Kagami Structure

const ownership = @import("mirai").kagami.types.ownership;
const state = @import("mirai").kagami.state;

pub const Kagami = struct {
    PML4Physical: u64 = 0,
    ReferenceCount: u32 = 1,
    ResidentPages: u64 = 0,
    WiredPages: u64 = 0,
    TablePages: u64 = 0,
    Lock: bool = false,
    Ownership: ownership.Ownership = .Borrowed,
    SharesKernel: bool = false,

    pub fn isKernel(self: *const Kagami) bool {
        return self == state.getKernelKagami() and self.Ownership == .Kernel;
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
