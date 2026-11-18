//! Portable Deadline Bound Socket Transfers

const builtin = @import("builtin");
const std = @import("std");

const limits = @import("tests").constants.runner;
const strings = @import("tests").strings.runner;

pub fn open(port: u16) !std.net.Stream {
    const address = try std.net.Address.parseIp4(strings.ADDRESS, port);
    const stream = try std.net.tcpConnectToAddress(address);
    errdefer stream.close();
    if (builtin.os.tag == .windows) {
        const timeout = limits.RECEIVE_MS;
        try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
        try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout));
    } else {
        const timeout: std.posix.timeval = .{ .sec = limits.RECEIVE_SECONDS, .usec = 0 };
        try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.RCVTIMEO, std.mem.asBytes(&timeout));
        try std.posix.setsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.SNDTIMEO, std.mem.asBytes(&timeout));
    }
    return stream;
}

pub fn startConnection(port: u16) !std.net.Stream {
    const address = try std.net.Address.parseIp4(strings.ADDRESS, port);
    const stream: std.net.Stream = .{
        .handle = try std.posix.socket(address.any.family, std.posix.SOCK.STREAM | std.posix.SOCK.CLOEXEC | std.posix.SOCK.NONBLOCK, std.posix.IPPROTO.TCP),
    };
    errdefer stream.close();
    std.posix.connect(stream.handle, &address.any, address.getOsSockLen()) catch |failure| switch (failure) {
        error.WouldBlock, error.ConnectionPending => {},
        else => return failure,
    };
    return stream;
}

pub fn checkConnection(stream: std.net.Stream) !void {
    var status: i32 = undefined;
    if (builtin.os.tag == .windows) {
        const network = std.os.windows.ws2_32;
        var length: i32 = @sizeOf(i32);
        if (network.getsockopt(stream.handle, network.SOL.SOCKET, network.SO.ERROR, @ptrCast(&status), &length) == network.SOCKET_ERROR) return socketError();
        if (length != @sizeOf(i32)) return error.PhaseChannelConnectionFailed;
    } else {
        try std.posix.getsockopt(stream.handle, std.posix.SOL.SOCKET, std.posix.SO.ERROR, std.mem.asBytes(&status));
    }
    if (status != 0) return error.PhaseChannelConnectionFailed;
}

pub fn receive(handle: std.net.Stream.Handle, bytes: []u8) !usize {
    if (builtin.os.tag != .windows) return std.posix.recv(handle, bytes, 0);
    const count = std.os.windows.ws2_32.recv(handle, bytes.ptr, @intCast(bytes.len), 0);
    if (count == std.os.windows.ws2_32.SOCKET_ERROR) return socketError();
    return @intCast(count);
}

pub fn send(handle: std.net.Stream.Handle, bytes: []const u8) !usize {
    if (builtin.os.tag != .windows) return std.posix.send(handle, bytes, 0);
    const count = std.os.windows.ws2_32.send(handle, bytes.ptr, @intCast(bytes.len), 0);
    if (count == std.os.windows.ws2_32.SOCKET_ERROR) return socketError();
    return @intCast(count);
}

fn socketError() anyerror {
    const reason = std.os.windows.ws2_32.WSAGetLastError();
    return switch (reason) {
        .WSAECONNRESET, .WSAECONNABORTED, .WSAENETRESET => error.ConnectionResetByPeer,
        .WSAEWOULDBLOCK, .WSAETIMEDOUT => error.ConnectionTimedOut,
        .WSAENOTCONN, .WSAESHUTDOWN => error.SocketNotConnected,
        .WSAEINTR, .WSA_OPERATION_ABORTED => error.Cancelled,
        else => failure: {
            std.log.err(strings.SOCKET_ERROR, .{@intFromEnum(reason)});
            break :failure error.UnexpectedSocketError;
        },
    };
}
