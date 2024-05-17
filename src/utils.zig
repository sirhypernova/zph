const std = @import("std");

pub const api_url = "https://api.github.com/repos/{s}/commits?per_page=1";
pub const archive_url = "https://github.com/{s}/archive/{s}.tar.gz";

pub fn getCommitsUrl(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, api_url, .{repo});
}

pub fn getArchiveUrl(allocator: std.mem.Allocator, repo: []const u8, commit: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, archive_url, .{ repo, commit });
}

pub fn makeRequest(allocator: std.mem.Allocator, url: []const u8) ![]const u8 {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();
    var response = std.ArrayList(u8).init(allocator);
    const res = try client.fetch(.{
        .method = .GET,
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &response },
    });
    if (res.status != .ok) return error.RequestFailed;
    return response.toOwnedSlice();
}

pub fn parseResponse(allocator: std.mem.Allocator, T: type, response: []const u8) !T {
    return try std.json.parseFromSliceLeaky(
        T,
        allocator,
        response,
        .{ .ignore_unknown_fields = true },
    );
}
