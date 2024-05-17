const std = @import("std");
const Ast = std.zig.Ast;

const configFile = @embedFile("./build.zig.zon");
// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zph",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const version: []const u8 = blk: {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        const allocator = gpa.allocator();
        defer _ = gpa.deinit();
        var ast = Ast.parse(allocator, configFile, .zon) catch unreachable;
        defer ast.deinit(allocator);

        const node_datas = ast.nodes.items(.data);
        const main_index = node_datas[0].lhs;

        var buf: [2]Ast.Node.Index = undefined;
        const struct_init = ast.fullStructInit(&buf, main_index) orelse unreachable;

        for (struct_init.ast.fields) |field_init| {
            const name_token = ast.firstToken(field_init) - 2;
            const field_name = try identifierTokenString(ast, name_token);
            if (std.mem.eql(u8, field_name, "version")) {
                break :blk try parseString(ast, field_init);
            }
        }
        break :blk "0.0.0";
    };

    const ops = b.addOptions();
    ops.addOption([]const u8, "version", version[1 .. version.len - 1]);
    const pkgMod = ops.createModule();
    exe.root_module.addImport("pkg", pkgMod);
    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

fn identifierTokenString(ast: Ast, token: Ast.TokenIndex) ![]const u8 {
    const token_tags = ast.tokens.items(.tag);
    std.debug.assert(token_tags[token] == .identifier);
    const ident_name = ast.tokenSlice(token);
    return ident_name;
}

fn parseString(ast: Ast, node: Ast.Node.Index) ![]const u8 {
    const node_tags = ast.nodes.items(.tag);
    const main_tokens = ast.nodes.items(.main_token);
    if (node_tags[node] != .string_literal) {
        @panic("expected string literal");
    }
    const str_lit_token = main_tokens[node];
    const token_bytes = ast.tokenSlice(str_lit_token);
    return token_bytes;
}
