//! Hikari Menu Renderer

const display = @import("../display/display.zig");
const theme_mod = @import("theme.zig");

pub const MenuItem = struct {
    label: []const u8,
    description: []const u8,
    enabled: bool,
};

pub const Renderer = struct {
    fb: *display.Framebuffer,
    text: *display.TextRenderer,
    theme: theme_mod.Theme,
    menu_x: u32,
    menu_y: u32,
    menu_width: u32,
    visible_items: u32,

    pub fn initialize(
        fb: *display.Framebuffer,
        text_renderer: *display.TextRenderer,
        theme: theme_mod.Theme,
    ) Renderer {
        const char_width = text_renderer.font.width;
        const char_height = text_renderer.font.height;

        const menu_width = 60;
        const menu_x = (text_renderer.columns - menu_width) / 2;
        const menu_y: u32 = 4;
        const visible_items = text_renderer.rows - 10;

        _ = char_width;
        _ = char_height;

        return Renderer{
            .fb = fb,
            .text = text_renderer,
            .theme = theme,
            .menu_x = menu_x,
            .menu_y = menu_y,
            .menu_width = menu_width,
            .visible_items = visible_items,
        };
    }

    pub fn draw_background(self: *Renderer) void {
        self.fb.clear(self.theme.background);
    }

    pub fn draw_title(self: *Renderer, title: []const u8) void {
        self.text.set_colors(self.theme.title_fg, self.theme.background);

        const title_x = (self.text.columns - @as(u32, @intCast(title.len))) / 2;
        self.text.set_cursor(title_x, 1);
        self.text.print(title);

        self.text.set_cursor(self.menu_x, 2);
        var i: u32 = 0;
        while (i < self.menu_width) : (i += 1) {
            self.text.put_char('-');
        }
    }

    pub fn draw_menu_items(
        self: *Renderer,
        items: []const MenuItem,
        selected: usize,
        scroll_offset: usize,
    ) void {
        var row: u32 = 0;
        while (row < self.visible_items and (scroll_offset + row) < items.len) : (row += 1) {
            const item_index = scroll_offset + row;
            const item = items[item_index];
            const is_selected = item_index == selected;

            self.draw_menu_item(item, row, is_selected);
        }
    }

    fn draw_menu_item(self: *Renderer, item: MenuItem, row: u32, selected: bool) void {
        const y = self.menu_y + row;

        if (selected) {
            self.text.set_colors(self.theme.highlight_fg, self.theme.highlight_bg);
        } else if (!item.enabled) {
            self.text.set_colors(self.theme.border, self.theme.background);
        } else {
            self.text.set_colors(self.theme.foreground, self.theme.background);
        }

        self.text.set_cursor(self.menu_x, y);

        if (selected) {
            self.text.print("> ");
        } else {
            self.text.print("  ");
        }

        self.text.print(item.label);

        var i: u32 = @intCast(item.label.len + 2);
        while (i < self.menu_width) : (i += 1) {
            self.text.put_char(' ');
        }
    }

    pub fn draw_description(self: *Renderer, description: []const u8) void {
        const desc_y = self.text.rows - 3;

        self.text.set_colors(self.theme.foreground, self.theme.background);
        self.text.set_cursor(self.menu_x, desc_y);

        var i: u32 = 0;
        while (i < self.menu_width) : (i += 1) {
            self.text.put_char(' ');
        }

        self.text.set_cursor(self.menu_x, desc_y);
        self.text.print(description);
    }

    pub fn draw_footer(self: *Renderer) void {
        const footer_y = self.text.rows - 1;

        self.text.set_colors(self.theme.border, self.theme.background);
        self.text.set_cursor(self.menu_x, footer_y);
        self.text.print("Up/Down: Navigate  Enter: Select  Esc: Cancel");
    }

    pub fn draw_scrollbar(self: *Renderer, total_items: usize, visible: usize, offset: usize) void {
        if (total_items <= visible) {
            return;
        }

        const scrollbar_x = self.menu_x + self.menu_width + 1;
        const scrollbar_height = self.visible_items;

        const thumb_height = (visible * scrollbar_height) / total_items;
        const thumb_height_clamped = if (thumb_height < 1) 1 else @as(u32, @intCast(thumb_height));

        const thumb_offset = (offset * scrollbar_height) / total_items;

        var i: u32 = 0;
        while (i < scrollbar_height) : (i += 1) {
            self.text.set_cursor(scrollbar_x, self.menu_y + i);

            if (i >= thumb_offset and i < thumb_offset + thumb_height_clamped) {
                self.text.set_colors(self.theme.highlight_bg, self.theme.background);
                self.text.put_char('#');
            } else {
                self.text.set_colors(self.theme.border, self.theme.background);
                self.text.put_char('|');
            }
        }
    }

    pub fn draw_progress(self: *Renderer, message: []const u8, percent: u32) void {
        const progress_y = self.text.rows / 2;
        const progress_width: u32 = 40;
        const progress_x = (self.text.columns - progress_width) / 2;

        self.text.set_colors(self.theme.foreground, self.theme.background);
        self.text.set_cursor((self.text.columns - @as(u32, @intCast(message.len))) / 2, progress_y - 1);
        self.text.print(message);

        self.text.set_cursor(progress_x, progress_y);
        self.text.put_char('[');

        const filled = (percent * (progress_width - 2)) / 100;
        var i: u32 = 0;
        while (i < progress_width - 2) : (i += 1) {
            if (i < filled) {
                self.text.set_colors(self.theme.success, self.theme.background);
                self.text.put_char('=');
            } else {
                self.text.set_colors(self.theme.border, self.theme.background);
                self.text.put_char('-');
            }
        }

        self.text.set_colors(self.theme.foreground, self.theme.background);
        self.text.put_char(']');
    }

    pub fn draw_message(self: *Renderer, message: []const u8, is_error: bool) void {
        const msg_y = self.text.rows / 2;

        if (is_error) {
            self.text.set_colors(self.theme.error_color, self.theme.background);
        } else {
            self.text.set_colors(self.theme.success, self.theme.background);
        }

        self.text.set_cursor((self.text.columns - @as(u32, @intCast(message.len))) / 2, msg_y);
        self.text.print(message);
    }
};
