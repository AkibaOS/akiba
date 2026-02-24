//! Hikari Menu Input

const efi = @import("../efi/efi.zig");

pub const InputAction = enum {
    none,
    up,
    down,
    select,
    cancel,
    page_up,
    page_down,
    home,
    end,
};

pub const Input = struct {
    system_table: *efi.services.SystemTable,

    pub fn initialize(system_table: *efi.services.SystemTable) Input {
        return Input{
            .system_table = system_table,
        };
    }

    pub fn poll(self: *Input) InputAction {
        var key: efi.types.input.InputKey = undefined;
        const status = self.system_table.console_input.read_key_stroke(
            self.system_table.console_input,
            &key,
        );

        if (efi.types.is_error(status)) {
            return .none;
        }

        if (key.scan_code != 0) {
            return switch (key.scan_code) {
                efi.constants.keyboard.scan_up => .up,
                efi.constants.keyboard.scan_down => .down,
                efi.constants.keyboard.scan_escape => .cancel,
                efi.constants.keyboard.scan_page_up => .page_up,
                efi.constants.keyboard.scan_page_down => .page_down,
                efi.constants.keyboard.scan_home => .home,
                efi.constants.keyboard.scan_end => .end,
                else => .none,
            };
        }

        if (key.unicode_char != 0) {
            return switch (key.unicode_char) {
                '\r', ' ' => .select,
                'j', 'J' => .down,
                'k', 'K' => .up,
                'q', 'Q' => .cancel,
                else => .none,
            };
        }

        return .none;
    }

    pub fn wait_for_key(self: *Input) void {
        var index: usize = 0;
        const events = [_]efi.types.Event{self.system_table.console_input.wait_for_key};
        _ = self.system_table.boot_services.wait_for_event(1, &events, &index);
    }

    pub fn wait_for_action(self: *Input) InputAction {
        while (true) {
            const action = self.poll();
            if (action != .none) {
                return action;
            }
            self.wait_for_key();
        }
    }

    pub fn clear_input_buffer(self: *Input) void {
        while (self.poll() != .none) {}
    }
};
