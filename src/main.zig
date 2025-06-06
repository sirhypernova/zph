const std = @import("std");
const pkg = @import("pkg");
const utils = @import("utils.zig");
const schemas = @import("schemas.zig");

const help =
    std.fmt.comptimePrint("zph v{s}\n", .{pkg.version}) ++
    \\Usage: zph <command> [...args]
    \\
    \\Commands:
    \\  help - Display this help message
    \\  version - Display the version of zph
    \\  fetch <user>/<repo>[@<tag>|latest] - Fetch a tag or the latest commits from a repository, and print the archive URL
    \\  save <user>/<repo>[@<tag>|latest] - Pass the archive URL to the package manager to save the package
    ;

const Command = enum {
    help,
    version,
    fetch,
    save,
};

pub fn main() !void {
    var stdout = std.io.getStdOut().writer();
    var stderr = std.io.getStdErr().writer();

    var arena_instance = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena_instance.deinit();
    const arena = arena_instance.allocator();

    var args = try std.process.argsWithAllocator(arena);
    defer args.deinit();
    _ = args.skip();

    if (args.next()) |cmd| {
        if (std.meta.stringToEnum(Command, cmd)) |command| {
            switch (command) {
                .help => try stdout.writeAll(help),
                .version => try stdout.print("zph v{s}\n", .{pkg.version}),
                .fetch, .save => {
                    if (args.next()) |repo| {
                        const tag_index = std.mem.indexOf(u8, repo, "@");
                        const archive_url = if (tag_index) |index| blk: {
                            const tag = repo[index + 1 ..];
                            if (tag.len == 0) {
                                try stdout.print("Missing tag argument\n{s}", .{help});
                                return;
                            }
                            const baseRepo = repo[0..index];
                            if (std.mem.eql(u8, tag, "latest"))
                                break :blk try fetchLatestTagUrl(arena, baseRepo);
                            break :blk try utils.getTagUrl(arena, baseRepo, tag);
                        } else fetchArchiveUrl(arena, repo) catch |err|
                            return handleError(err, stderr.any(), .{repo});
                        if (command == .fetch) {
                            try stdout.writeAll(archive_url);
                        } else {
                            try stdout.writeAll("Saving repository..\n");
                            const res = try std.process.Child.run(.{
                                .allocator = arena,
                                .argv = &[_][]const u8{ "zig", "fetch", "--save", archive_url },
                            });
                            if (res.stderr.len > 0) try stderr.writeAll(res.stderr);
                            if (res.stdout.len > 0) try stdout.writeAll(res.stdout);
                            try stdout.writeAll("Package saved.");
                        }
                    } else {
                        try stdout.print("Missing repository argument\n{s}", .{help});
                    }
                },
            }
        } else {
            try stdout.print("Unknown command \"{s}\"\n{s}", .{ cmd, help });
        }
    } else try stdout.writeAll(help);
}

fn handleError(err: anyerror, output: std.io.AnyWriter, args: anytype) !void {
    if (err == error.RequestFailed) {
        try output.print(
            \\Failed to fetch commits for repository "{s}"
            \\Please check the repository name and try again.
        , args);
    } else {
        try output.print("An error occurred: {any}\n", .{err});
    }
}

fn fetchArchiveUrl(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    const api_url = try utils.getCommitsUrl(allocator, repo);
    const result = try utils.makeRequest(allocator, api_url);
    const parsed: schemas.Commits = try utils.parseResponse(allocator, schemas.Commits, result);

    return utils.getArchiveUrl(allocator, repo, parsed[0].sha);
}

fn fetchLatestTagUrl(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    const api_url = try utils.getLatestTagUrl(allocator, repo);
    const result = try utils.makeRequest(allocator, api_url);
    const parsed: schemas.LatestTag = try utils.parseResponse(allocator, schemas.LatestTag, result);

    return utils.getTagUrl(allocator, repo, parsed.tag_name);
}
