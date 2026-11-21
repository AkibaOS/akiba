//! Validate And Order Service Dependencies Before Startup

const std = @import("std");

const Job = @import("pulse").world.types.parse.document.Job;
const WorldError = @import("pulse").world.errors.parse.document.WorldError;

pub fn order(allocator: std.mem.Allocator, jobs: []const Job) WorldError![]usize {
    for (jobs, 0..) |job, index| {
        for (jobs[0..index]) |earlier| if (std.mem.eql(u8, job.Name, earlier.Name)) return error.DuplicateService;
        for (job.After) |name| if (find(jobs, name) == null) return error.MissingDependency;
    }
    const result = try allocator.alloc(usize, jobs.len);
    errdefer allocator.free(result);
    const placed = try allocator.alloc(bool, jobs.len);
    defer allocator.free(placed);
    @memset(placed, false);
    var count: usize = 0;
    while (count < jobs.len) {
        const previous = count;
        for (jobs, 0..) |job, index| {
            if (placed[index]) continue;
            var ready = true;
            for (job.After) |name| {
                const dependency = find(jobs, name) orelse return error.MissingDependency;
                if (!placed[dependency]) ready = false;
            }
            if (!ready) continue;
            placed[index] = true;
            result[count] = index;
            count += 1;
        }
        if (previous == count) return error.DependencyCycle;
    }
    return result;
}

pub fn find(jobs: []const Job, name: []const u8) ?usize {
    for (jobs, 0..) |job, index| if (std.mem.eql(u8, job.Name, name)) return index;
    return null;
}
