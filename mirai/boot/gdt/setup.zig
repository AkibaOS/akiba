//! GDT Setup

const constants = @import("mirai").boot.constants;
const load = @import("mirai").boot.gdt.load;
const state = @import("mirai").boot.gdt.state;

const selectors = constants.gdt.selectors;

pub fn initialize(tss_address: u64, tss_size: u20) void {
    state.setupEntries(tss_address, tss_size);

    const descriptor = state.getGDTR();
    load.loadTable(&descriptor);

    load.reloadSegments();

    load.loadTaskStateSegment(selectors.TSS_SELECTOR);

    state.setInitialized();
}
