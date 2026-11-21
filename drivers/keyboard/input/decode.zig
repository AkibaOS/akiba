//! Translate Set 1 Input Into Text And Navigation Events

const scan = @import("keyboard").constants.input.scancode;
const text = @import("keyboard").input.text;

const Event = @import("shared").keyboard.types.event.Event;
const Key = @import("shared").keyboard.types.event.Key;
const Modifiers = @import("shared").keyboard.types.event.Modifiers;
const State = @import("keyboard").types.input.state.State;

pub fn feed(state: *State, byte: u8) ?Event {
    if (state.PauseIndex != 0) {
        const index = state.PauseIndex - 1;
        if (byte == scan.PAUSE_TAIL[index]) {
            if (state.PauseIndex == scan.PAUSE_TAIL.len) {
                state.PauseIndex = 0;
                return keyEvent(state, .Pause);
            }
            state.PauseIndex += 1;
            return null;
        }
        state.PauseIndex = 0;
    }
    switch (byte) {
        scan.EXTENDED => {
            state.Extended = true;
            return null;
        },
        scan.PAUSE_PREFIX => {
            state.Extended = false;
            state.PauseIndex = 1;
            return null;
        },
        else => {},
    }
    const extended = state.Extended;
    state.Extended = false;
    const pressed = byte & scan.BREAK_MASK == 0;
    const code = byte & ~scan.BREAK_MASK;
    if (modifier(state, code, extended, pressed) or !pressed) return null;
    if (editing(code, extended)) |key| return keyEvent(state, key);
    if (extended) return null;
    const active = modifiers(state);
    const character = text.character(code, active.Shift, active.CapsLock) orelse return null;
    return .{ .Kind = .Text, .Modifiers = active, .Value = character };
}

fn modifier(state: *State, code: u8, extended: bool, pressed: bool) bool {
    switch (code) {
        scan.LEFT_SHIFT => if (!extended) {
            state.LeftShift = pressed;
        },
        scan.RIGHT_SHIFT => if (!extended) {
            state.RightShift = pressed;
        },
        scan.CONTROL => if (extended) {
            state.RightControl = pressed;
        } else {
            state.LeftControl = pressed;
        },
        scan.ALT => if (extended) {
            state.RightAlt = pressed;
        } else {
            state.LeftAlt = pressed;
        },
        scan.CAPS_LOCK => if (!extended) {
            if (pressed and !state.CapsHeld) state.CapsLock = !state.CapsLock;
            state.CapsHeld = pressed;
        },
        else => return false,
    }
    return true;
}

fn editing(code: u8, extended: bool) ?Key {
    return if (extended) switch (code) {
        scan.ENTER => .Enter,
        scan.HOME => .Home,
        scan.UP => .Up,
        scan.PAGE_UP => .PageUp,
        scan.LEFT => .Left,
        scan.RIGHT => .Right,
        scan.END => .End,
        scan.DOWN => .Down,
        scan.PAGE_DOWN => .PageDown,
        scan.INSERT => .Insert,
        scan.DELETE => .Delete,
        else => null,
    } else switch (code) {
        scan.ESCAPE => .Escape,
        scan.BACKSPACE => .Backspace,
        scan.TAB => .Tab,
        scan.ENTER => .Enter,
        else => null,
    };
}

fn keyEvent(state: *const State, key: Key) Event {
    return .{ .Kind = .Key, .Modifiers = modifiers(state), .Value = @intFromEnum(key) };
}

fn modifiers(state: *const State) Modifiers {
    return .{
        .Shift = state.LeftShift or state.RightShift,
        .Control = state.LeftControl or state.RightControl,
        .Alt = state.LeftAlt or state.RightAlt,
        .CapsLock = state.CapsLock,
    };
}
