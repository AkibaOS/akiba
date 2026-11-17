//! Stable Sparse Crimson Owner Port Registry

const guard = @import("asm").interrupts.guard;
const memory = @import("mirai").memory;
const strings = @import("mirai").crimson.strings.ports;
const tree = @import("common").datatypes.tree;
const types = @import("mirai").crimson.types;

const Entry = types.ports.record.Entry;
const ExceptionType = types.kind.ExceptionType;
const Port = types.port.Port;
const Store = memory.types.pool.store.create(Entry);
const Tree = tree.types.index.Tree;

pub const Registry = struct {
    Records: Store = .{},
    Identities: Tree = .{},

    const Self = @This();

    pub fn getPort(self: *const Self, owner_id: u64, exception_type: ExceptionType) *const Port {
        const flags = guard.acquire();
        defer guard.release(flags);
        const entry = self.find(owner_id) orelse return &Port.EMPTY;
        return entry.Ports.getConst(exception_type);
    }

    pub fn hasPort(self: *const Self, owner_id: u64, exception_type: ExceptionType) bool {
        const flags = guard.acquire();
        defer guard.release(flags);
        const entry = self.find(owner_id) orelse return false;
        return entry.Ports.hasPort(exception_type);
    }

    pub fn setPort(self: *Self, owner_id: u64, exception_type: ExceptionType, port: Port, name: []const u8) bool {
        const flags = guard.acquire();
        defer guard.release(flags);
        if (self.find(owner_id)) |entry| {
            entry.Ports.set(exception_type, port);
            return true;
        }
        if (self.Records.Zone == null) self.Records.init(name) catch return false;
        const entry = self.Records.reserve() catch {
            self.releaseEmpty();
            return false;
        };
        entry.* = .{ .OwnerId = owner_id };
        entry.Ports.set(exception_type, port);
        if (!tree.insert.insert(&self.Identities, &entry.Index, owner_id)) {
            self.discard(entry);
            return false;
        }
        return true;
    }

    pub fn clearPort(self: *Self, owner_id: u64, exception_type: ExceptionType) bool {
        const flags = guard.acquire();
        defer guard.release(flags);
        const entry = self.find(owner_id) orelse return true;
        entry.Ports.get(exception_type).clear();
        if (entry.Ports.isEmpty()) self.remove(entry);
        return true;
    }

    pub fn clearAll(self: *Self, owner_id: u64) bool {
        const flags = guard.acquire();
        defer guard.release(flags);
        const entry = self.find(owner_id) orelse return true;
        self.remove(entry);
        return true;
    }

    fn find(self: *const Self, owner_id: u64) ?*Entry {
        const node = tree.lookup.find(&self.Identities, owner_id) orelse return null;
        return @fieldParentPtr(strings.INDEX_FIELD, node);
    }

    fn remove(self: *Self, entry: *Entry) void {
        if (!tree.remove.remove(&self.Identities, &entry.Index)) @panic(strings.INVALID_REGISTRY);
        self.discard(entry);
    }

    fn discard(self: *Self, entry: *Entry) void {
        if (!self.Records.release(entry)) @panic(strings.INVALID_REGISTRY);
        _ = self.Records.collectAt(entry);
        self.releaseEmpty();
    }

    fn releaseEmpty(self: *Self) void {
        if (self.Records.Count != 0) return;
        if (self.Identities.Count != 0 or self.Identities.Root != null) @panic(strings.INVALID_REGISTRY);
        if (self.Records.Zone != null and !self.Records.deinit()) @panic(strings.INVALID_REGISTRY);
    }
};
