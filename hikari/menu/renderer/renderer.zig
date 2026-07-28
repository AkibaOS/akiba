//! Hikari Menu Renderer

const constants = @import("hikari").menu.constants;
const display = @import("hikari").display;
const strings = @import("hikari").menu.strings;
const theme = @import("hikari").menu.theme;

const layout = constants.layout;

pub const MenuItem = struct {
    Label: []const u8,
    Description: []const u8,
    Enabled: bool,
};

pub const Renderer = struct {
    Framebuffer: *display.framebuffer.Framebuffer,
    Text: *display.text.TextRenderer,
    Theme: theme.Theme,
    MenuX: u32,
    MenuY: u32,
    MenuWidth: u32,
    VisibleItems: u32,

    pub fn initialize(
        framebuffer: *display.framebuffer.Framebuffer,
        text_renderer: *display.text.TextRenderer,
        menu_theme: theme.Theme,
    ) Renderer {
        const menu_x = (text_renderer.Columns - layout.MENU_WIDTH) / 2;
        const visible_items = text_renderer.Rows - layout.RESERVED_ROWS;

        return Renderer{
            .Framebuffer = framebuffer,
            .Text = text_renderer,
            .Theme = menu_theme,
            .MenuX = menu_x,
            .MenuY = layout.MENU_START_ROW,
            .MenuWidth = layout.MENU_WIDTH,
            .VisibleItems = visible_items,
        };
    }

    pub fn drawBackground(self: *Renderer) void {
        self.Framebuffer.clear(self.Theme.Background);
    }

    pub fn drawTitle(self: *Renderer, title: []const u8) void {
        self.Text.setColors(self.Theme.TitleForeground, self.Theme.Background);

        const title_x = (self.Text.Columns - @as(u32, @intCast(title.len))) / 2;
        self.Text.setCursor(title_x, layout.TITLE_ROW);
        self.Text.print(title);

        self.Text.setCursor(self.MenuX, layout.SEPARATOR_ROW);
        var column: u32 = 0;
        while (column < self.MenuWidth) : (column += 1) {
            self.Text.putChar('-');
        }
    }

    pub fn drawMenuItems(
        self: *Renderer,
        items: []const MenuItem,
        selected: usize,
        scroll_offset: usize,
    ) void {
        var row: u32 = 0;
        while (row < self.VisibleItems and (scroll_offset + row) < items.len) : (row += 1) {
            const item_index = scroll_offset + row;
            const item = items[item_index];
            const is_selected = item_index == selected;

            self.drawMenuItem(item, row, is_selected);
        }
    }

    fn drawMenuItem(self: *Renderer, item: MenuItem, row: u32, selected: bool) void {
        const y = self.MenuY + row;

        if (selected) {
            self.Text.setColors(self.Theme.HighlightForeground, self.Theme.HighlightBackground);
        } else if (!item.Enabled) {
            self.Text.setColors(self.Theme.Border, self.Theme.Background);
        } else {
            self.Text.setColors(self.Theme.Foreground, self.Theme.Background);
        }

        self.Text.setCursor(self.MenuX, y);

        if (selected) {
            self.Text.print(strings.renderer.SELECTION_MARKER);
        } else {
            self.Text.print(strings.renderer.NO_SELECTION_MARKER);
        }

        self.Text.print(item.Label);

        var column: u32 = @as(u32, @intCast(item.Label.len)) + layout.SELECTION_MARKER_WIDTH;
        while (column < self.MenuWidth) : (column += 1) {
            self.Text.putChar(' ');
        }
    }

    pub fn drawDescription(self: *Renderer, description: []const u8) void {
        const description_row = self.Text.Rows - layout.DESCRIPTION_ROWS_FROM_BOTTOM;

        self.Text.setColors(self.Theme.Foreground, self.Theme.Background);
        self.Text.setCursor(self.MenuX, description_row);

        var column: u32 = 0;
        while (column < self.MenuWidth) : (column += 1) {
            self.Text.putChar(' ');
        }

        self.Text.setCursor(self.MenuX, description_row);
        self.Text.print(description);
    }

    pub fn drawFooter(self: *Renderer) void {
        const footer_row = self.Text.Rows - layout.FOOTER_ROWS_FROM_BOTTOM;

        self.Text.setColors(self.Theme.Border, self.Theme.Background);
        self.Text.setCursor(self.MenuX, footer_row);
        self.Text.print(strings.renderer.FOOTER);
    }

    pub fn drawScrollbar(self: *Renderer, total_items: usize, visible: usize, offset: usize) void {
        if (total_items <= visible) {
            return;
        }

        const scrollbar_x = self.MenuX + self.MenuWidth + 1;
        const scrollbar_height = self.VisibleItems;

        const thumb_height = (visible * scrollbar_height) / total_items;
        const thumb_height_clamped = if (thumb_height < 1) 1 else @as(u32, @intCast(thumb_height));

        const thumb_offset = (offset * scrollbar_height) / total_items;

        var row: u32 = 0;
        while (row < scrollbar_height) : (row += 1) {
            self.Text.setCursor(scrollbar_x, self.MenuY + row);

            if (row >= thumb_offset and row < thumb_offset + thumb_height_clamped) {
                self.Text.setColors(self.Theme.HighlightBackground, self.Theme.Background);
                self.Text.putChar('#');
            } else {
                self.Text.setColors(self.Theme.Border, self.Theme.Background);
                self.Text.putChar('|');
            }
        }
    }

    pub fn drawProgress(self: *Renderer, message: []const u8, percent: u32) void {
        const progress_row = self.Text.Rows / 2;
        const progress_x = (self.Text.Columns - layout.PROGRESS_WIDTH) / 2;

        self.Text.setColors(self.Theme.Foreground, self.Theme.Background);
        self.Text.setCursor((self.Text.Columns - @as(u32, @intCast(message.len))) / 2, progress_row - 1);
        self.Text.print(message);

        self.Text.setCursor(progress_x, progress_row);
        self.Text.putChar('[');

        const filled = (percent * (layout.PROGRESS_WIDTH - 2)) / layout.PERCENT_MAX;
        var column: u32 = 0;
        while (column < layout.PROGRESS_WIDTH - 2) : (column += 1) {
            if (column < filled) {
                self.Text.setColors(self.Theme.Success, self.Theme.Background);
                self.Text.putChar('=');
            } else {
                self.Text.setColors(self.Theme.Border, self.Theme.Background);
                self.Text.putChar('-');
            }
        }

        self.Text.setColors(self.Theme.Foreground, self.Theme.Background);
        self.Text.putChar(']');
    }

    pub fn drawMessage(self: *Renderer, message: []const u8, is_error: bool) void {
        const message_row = self.Text.Rows / 2;

        if (is_error) {
            self.Text.setColors(self.Theme.ErrorColor, self.Theme.Background);
        } else {
            self.Text.setColors(self.Theme.Success, self.Theme.Background);
        }

        self.Text.setCursor((self.Text.Columns - @as(u32, @intCast(message.len))) / 2, message_row);
        self.Text.print(message);
    }
};
