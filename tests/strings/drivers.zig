//! Hardware Device Probe Labels

pub const GROUP = "CHECK GROUP Hardware devices\n";
pub const READY = "CHECK DEVICE INPUT READY";
pub const READY_LINE = READY ++ "\n";
pub const SERIAL = "emergency serial remains available after actual boot output";
pub const TIMER = "actual PIT interrupts advance the monotonic driver tick count";
pub const KEYBOARD = "injected keyboard input reaches the real IRQ scan-code handler";
