//! Adapt An Authenticated AFS Client To Installed Bundle Access

const std = @import("std");

const service = @import("shared").afs.service.client;

const Client = @import("shared").afs.types.service.client.Client;
const Entry = @import("shared").afs.types.read.list.Entry;
const ReadError = @import("shared").bundle.errors.installed.reader.ReadError;
const Reader = @import("shared").bundle.types.installed.reader.Reader;

pub fn fromAfs(client: *Client) Reader {
    return .{ .Context = client, .Read = read, .Size = size, .List = list };
}

fn read(context: *anyopaque, allocator: std.mem.Allocator, path: []const u8, maximum: usize) ReadError!?[]u8 {
    const client: *Client = @ptrCast(@alignCast(context));
    return service.readWithin(client.*, allocator, path, maximum);
}

fn size(context: *anyopaque, path: []const u8) ReadError!?u64 {
    const client: *Client = @ptrCast(@alignCast(context));
    return service.stat(client.*, path);
}

fn list(context: *anyopaque, path: []const u8, index: u64) ReadError!?Entry {
    const client: *Client = @ptrCast(@alignCast(context));
    return service.list(client.*, path, index);
}
