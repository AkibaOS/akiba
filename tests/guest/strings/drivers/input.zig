//! Hardware Device Probe Labels

pub const SERIAL = "emergency serial remains available after actual boot output";
pub const TIMER = "actual PIT interrupts advance the monotonic driver tick count";
pub const NORMALIZED = "the installed keyboard driver returns exactly one typed event for each injected key";
pub const KEYBOARD = "injected keyboard input reaches the real IRQ scan-code handler";
