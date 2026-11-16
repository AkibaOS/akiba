//! Portable Deadline Bound Socket Transfers

const builtin = @import("builtin");
const std = @import("std");

const strings = @import("checks").strings.runner;

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
