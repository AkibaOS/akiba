//! Hardware Device Probe Labels

pub const SERIAL = "emergency serial remains available after actual boot output";
pub const TIMER = "actual PIT interrupts advance the monotonic driver tick count";
pub const PRESENTATION = "the installed display driver presents valid rectangles and refuses an edge crossing";
pub const NORMALIZED = "the installed keyboard driver returns exactly one typed event for each injected key";
pub const KEYBOARD = "injected keyboard input reaches the real IRQ scan-code handler";
pub const INSTANCES = "boot keyboard and scanout are distinct device instances";
pub const PENDING_ASSIGNMENT = "an unpublished device reservation cannot be used by its Kata";
pub const DEVICE_CONTENTION = "a second Kata cannot reserve the same pending device";
pub const REBOUND_ASSIGNMENT = "destroying an unpublished Kata releases its instance without reusing assignment handles";
pub const REBOUND_DRIVER = "Pulse reattaches the keyboard instance to a new Kata after the old driver stops";
