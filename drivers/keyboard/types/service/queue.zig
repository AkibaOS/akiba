//! One Page Of Pending Normalized Key Events

const sizes = @import("common").constants.memory.sizes;

const Event = @import("shared").keyboard.types.event.Event;

pub const Queue = struct {
    Events: [sizes.PAGE_SIZE / @sizeOf(Event)]Event = undefined,
    Head: usize = 0,
    Count: usize = 0,
    Lost: bool = false,
};
