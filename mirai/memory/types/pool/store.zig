//! Stable Typed Storage

const std = @import("std");

const common = @import("common");
const fields = @import("mirai").memory.strings.pool.fields;
const guard = @import("asm").interrupts.guard;
const records = @import("mirai").memory.types.pool.record;
const types = @import("mirai").memory.types;
const zone = @import("mirai").memory.zone;

const sizes = common.constants.memory.sizes;
const AllocationError = common.errors.memory.allocation.AllocationError;
const Zone = types.zone.Zone;

pub fn create(comptime Value: type) type {
    const Record = records.create(Value);
    return struct {
        const Self = @This();

        Zone: ?*Zone = null,
        Count: usize = 0,
        LastGeneration: u64 = 0,
        Location: usize = 0,
        Head: ?*Record = null,
        Tail: ?*Record = null,

        pub fn init(self: *Self, name: []const u8) AllocationError!void {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (self.Zone != null) {
                if (!self.valid()) return AllocationError.InvalidSize;
                return;
            }
            if (self.Location != 0 or self.Count != 0 or self.Head != null or self.Tail != null) return AllocationError.InvalidSize;
            if (@alignOf(Record) > sizes.PAGE_SIZE) return AllocationError.InvalidAlignment;
            if (@sizeOf(Record) > sizes.PAGE_SIZE) return AllocationError.SizeTooLarge;
            self.Zone = try zone.create.create(name, @sizeOf(Record));
            self.Location = @intFromPtr(self);
        }

        pub fn reserve(self: *Self) AllocationError!*Value {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (!self.valid()) return AllocationError.NotInitialized;
            if (self.LastGeneration == std.math.maxInt(u64) or self.Count == std.math.maxInt(usize)) return AllocationError.RegionExhausted;
            const pointer = try zone.alloc.zalloc(self.Zone.?);
            const record: *Record = @ptrCast(@alignCast(pointer));
            record.* = .{ .Previous = self.Tail, .Generation = self.LastGeneration + 1 };
            if (self.Tail) |tail| {
                tail.Next = record;
            } else {
                self.Head = record;
            }
            self.Tail = record;
            self.LastGeneration = record.Generation;
            self.Count += 1;
            return &record.Value;
        }

        pub fn release(self: *Self, value: *Value) bool {
            const flags = guard.acquire();
            defer guard.release(flags);
            const record = self.findRecord(value) orelse return false;
            if (self.Count == 0) return false;
            if (record.Previous) |previous| {
                previous.Next = record.Next;
            } else {
                self.Head = record.Next;
            }
            if (record.Next) |next_record| {
                next_record.Previous = record.Previous;
            } else {
                self.Tail = record.Previous;
            }
            self.Count -= 1;
            zone.alloc.zfree(self.Zone.?, @ptrCast(record));
            return true;
        }

        pub fn owns(self: *const Self, value: *const Value) bool {
            const flags = guard.acquire();
            defer guard.release(flags);
            return self.findRecord(value) != null;
        }

        pub fn generation(self: *const Self, value: *const Value) ?u64 {
            const flags = guard.acquire();
            defer guard.release(flags);
            const record = self.findRecord(value) orelse return null;
            return record.Generation;
        }

        pub fn first(self: *const Self) ?*Value {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (!self.valid()) return null;
            const record = self.Head orelse return null;
            return &record.Value;
        }

        pub fn next(self: *const Self, value: *const Value) ?*Value {
            const flags = guard.acquire();
            defer guard.release(flags);
            const record = self.findRecord(value) orelse return null;
            const following = record.Next orelse return null;
            return &following.Value;
        }

        pub fn collect(self: *Self) usize {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (!self.valid()) return 0;
            return zone.gc.collect(self.Zone.?);
        }

        pub fn collectAt(self: *Self, value: *const Value) usize {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (!self.valid()) return 0;
            const address = recordAddress(value) orelse return 0;
            return zone.gc.collectPage(self.Zone.?, @ptrFromInt(address));
        }

        pub fn deinit(self: *Self) bool {
            const flags = guard.acquire();
            defer guard.release(flags);
            if (!self.valid() or self.Count != 0 or self.Head != null or self.Tail != null) return false;
            if (!zone.destroy.destroy(self.Zone.?)) return false;
            self.Zone = null;
            self.Location = 0;
            return true;
        }

        fn valid(self: *const Self) bool {
            return self.Zone != null and self.Location == @intFromPtr(self);
        }

        fn recordAddress(value: *const Value) ?usize {
            const address = @intFromPtr(value);
            const offset = @offsetOf(Record, fields.VALUE);
            if (address < offset) return null;
            const record_address = address - offset;
            if (record_address == 0 or record_address % @alignOf(Record) != 0) return null;
            return record_address;
        }

        fn findRecord(self: *const Self, value: *const Value) ?*Record {
            if (!self.valid()) return null;
            const address = recordAddress(value) orelse return null;
            const pointer: *const anyopaque = @ptrFromInt(address);
            if (!zone.alloc.owns(self.Zone.?, pointer)) return null;
            return @ptrFromInt(address);
        }
    };
}
