//! Hikari Menu Subsystem

pub const theme = @import("theme.zig");
pub const input = @import("input.zig");
pub const renderer = @import("renderer.zig");

pub const Theme = theme.Theme;
pub const Input = input.Input;
pub const InputAction = input.InputAction;
pub const Renderer = renderer.Renderer;
pub const MenuItem = renderer.MenuItem;

pub const BootMenu = struct {
    renderer: *Renderer,
    input: *Input,
    items: []const MenuItem,
    selected: usize,
    scroll_offset: usize,
    title: []const u8,

    pub fn initialize(
        menu_renderer: *Renderer,
        menu_input: *Input,
        items: []const MenuItem,
        title: []const u8,
    ) BootMenu {
        return BootMenu{
            .renderer = menu_renderer,
            .input = menu_input,
            .items = items,
            .selected = 0,
            .scroll_offset = 0,
            .title = title,
        };
    }

    pub fn run(self: *BootMenu) ?usize {
        self.input.clear_input_buffer();
        self.draw();

        while (true) {
            const action = self.input.wait_for_action();

            switch (action) {
                .up => self.move_up(),
                .down => self.move_down(),
                .page_up => self.page_up(),
                .page_down => self.page_down(),
                .home => self.go_home(),
                .end => self.go_end(),
                .select => {
                    if (self.items[self.selected].enabled) {
                        return self.selected;
                    }
                },
                .cancel => return null,
                .none => {},
            }

            self.draw();
        }
    }

    fn draw(self: *BootMenu) void {
        self.renderer.draw_background();
        self.renderer.draw_title(self.title);
        self.renderer.draw_menu_items(self.items, self.selected, self.scroll_offset);
        self.renderer.draw_description(self.items[self.selected].description);
        self.renderer.draw_scrollbar(self.items.len, self.renderer.visible_items, self.scroll_offset);
        self.renderer.draw_footer();
    }

    fn move_up(self: *BootMenu) void {
        if (self.selected > 0) {
            self.selected -= 1;
            if (self.selected < self.scroll_offset) {
                self.scroll_offset = self.selected;
            }
        }
    }

    fn move_down(self: *BootMenu) void {
        if (self.selected < self.items.len - 1) {
            self.selected += 1;
            if (self.selected >= self.scroll_offset + self.renderer.visible_items) {
                self.scroll_offset = self.selected - self.renderer.visible_items + 1;
            }
        }
    }

    fn page_up(self: *BootMenu) void {
        if (self.selected >= self.renderer.visible_items) {
            self.selected -= self.renderer.visible_items;
        } else {
            self.selected = 0;
        }
        if (self.selected < self.scroll_offset) {
            self.scroll_offset = self.selected;
        }
    }

    fn page_down(self: *BootMenu) void {
        const remaining = self.items.len - 1 - self.selected;
        if (remaining >= self.renderer.visible_items) {
            self.selected += self.renderer.visible_items;
        } else {
            self.selected = self.items.len - 1;
        }
        if (self.selected >= self.scroll_offset + self.renderer.visible_items) {
            self.scroll_offset = self.selected - self.renderer.visible_items + 1;
        }
    }

    fn go_home(self: *BootMenu) void {
        self.selected = 0;
        self.scroll_offset = 0;
    }

    fn go_end(self: *BootMenu) void {
        self.selected = self.items.len - 1;
        if (self.items.len > self.renderer.visible_items) {
            self.scroll_offset = self.items.len - self.renderer.visible_items;
        }
    }
};
