//! Splash Handoff State

const splash = @import("shared").splash;

const text = @import("utils").text.ascii;

const limits = splash.constants.limits;

pub const SplashState = extern struct {
    TrailText: [limits.TRAIL_LINES][limits.MESSAGE_CAPACITY]u8,
    TrailLength: [limits.TRAIL_LINES]u8,
    ProgressStep: u8,
    ProgressTotal: u8,
    Active: u8,
    Failed: u8,

    pub fn initialize(total_steps: u8) SplashState {
        return SplashState{
            .TrailText = [_][limits.MESSAGE_CAPACITY]u8{[_]u8{0} ** limits.MESSAGE_CAPACITY} ** limits.TRAIL_LINES,
            .TrailLength = [_]u8{0} ** limits.TRAIL_LINES,
            .ProgressStep = 0,
            .ProgressTotal = total_steps,
            .Active = 0,
            .Failed = 0,
        };
    }

    pub fn pushMessage(self: *SplashState, message: []const u8) void {
        var index: usize = 0;
        while (index + 1 < limits.TRAIL_LINES) : (index += 1) {
            self.TrailText[index] = self.TrailText[index + 1];
            self.TrailLength[index] = self.TrailLength[index + 1];
        }

        const newest = limits.TRAIL_LINES - 1;
        const copied = text.copyBounded(&self.TrailText[newest], message);
        self.TrailLength[newest] = @truncate(copied);

        if (self.ProgressStep < self.ProgressTotal) {
            self.ProgressStep += 1;
        }
    }

    pub fn line(self: *const SplashState, index: usize) []const u8 {
        return self.TrailText[index][0..self.TrailLength[index]];
    }

    pub fn isActive(self: *const SplashState) bool {
        return self.Active != 0;
    }

    pub fn hasFailed(self: *const SplashState) bool {
        return self.Failed != 0;
    }
};
