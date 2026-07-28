//! Hikari Boot Menu

const input = @import("hikari").menu.input;
const renderer = @import("hikari").menu.renderer;

pub const BootMenu = struct {
    Renderer: *renderer.Renderer,
    Input: *input.Input,
    Items: []const renderer.MenuItem,
    Selected: usize,
    ScrollOffset: usize,
    Title: []const u8,

    pub fn initialize(
        menu_renderer: *renderer.Renderer,
        menu_input: *input.Input,
        items: []const renderer.MenuItem,
        title: []const u8,
    ) BootMenu {
        return BootMenu{
            .Renderer = menu_renderer,
            .Input = menu_input,
            .Items = items,
            .Selected = 0,
            .ScrollOffset = 0,
            .Title = title,
        };
    }

    pub fn run(self: *BootMenu) ?usize {
        self.Input.clearInputBuffer();
        self.draw();

        while (true) {
            const action = self.Input.waitForAction();

            switch (action) {
                .Up => self.moveUp(),
                .Down => self.moveDown(),
                .PageUp => self.pageUp(),
                .PageDown => self.pageDown(),
                .Home => self.goHome(),
                .End => self.goEnd(),
                .Select => {
                    if (self.Items[self.Selected].Enabled) {
                        return self.Selected;
                    }
                },
                .Cancel => return null,
                .None => {},
            }

            self.draw();
        }
    }

    fn draw(self: *BootMenu) void {
        self.Renderer.drawBackground();
        self.Renderer.drawTitle(self.Title);
        self.Renderer.drawMenuItems(self.Items, self.Selected, self.ScrollOffset);
        self.Renderer.drawDescription(self.Items[self.Selected].Description);
        self.Renderer.drawScrollbar(self.Items.len, self.Renderer.VisibleItems, self.ScrollOffset);
        self.Renderer.drawFooter();
    }

    fn moveUp(self: *BootMenu) void {
        if (self.Selected > 0) {
            self.Selected -= 1;
            if (self.Selected < self.ScrollOffset) {
                self.ScrollOffset = self.Selected;
            }
        }
    }

    fn moveDown(self: *BootMenu) void {
        if (self.Selected < self.Items.len - 1) {
            self.Selected += 1;
            if (self.Selected >= self.ScrollOffset + self.Renderer.VisibleItems) {
                self.ScrollOffset = self.Selected - self.Renderer.VisibleItems + 1;
            }
        }
    }

    fn pageUp(self: *BootMenu) void {
        if (self.Selected >= self.Renderer.VisibleItems) {
            self.Selected -= self.Renderer.VisibleItems;
        } else {
            self.Selected = 0;
        }
        if (self.Selected < self.ScrollOffset) {
            self.ScrollOffset = self.Selected;
        }
    }

    fn pageDown(self: *BootMenu) void {
        const remaining = self.Items.len - 1 - self.Selected;
        if (remaining >= self.Renderer.VisibleItems) {
            self.Selected += self.Renderer.VisibleItems;
        } else {
            self.Selected = self.Items.len - 1;
        }
        if (self.Selected >= self.ScrollOffset + self.Renderer.VisibleItems) {
            self.ScrollOffset = self.Selected - self.Renderer.VisibleItems + 1;
        }
    }

    fn goHome(self: *BootMenu) void {
        self.Selected = 0;
        self.ScrollOffset = 0;
    }

    fn goEnd(self: *BootMenu) void {
        self.Selected = self.Items.len - 1;
        if (self.Items.len > self.Renderer.VisibleItems) {
            self.ScrollOffset = self.Items.len - self.Renderer.VisibleItems;
        }
    }
};
