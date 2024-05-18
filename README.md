# zph

### Zig Package Helper

![License Badge](https://img.shields.io/badge/license-MIT-green)

## Usage

Run `zig build` to build zph. I recommend building zph in one of the release modes, as it will be much faster.

Once that is done, you will find the executable in `zig-out/bin/zph`. Executing it will display the help menu.

If you would like to have zph available globally, you can add the bin directory to your `PATH` environment variable, or copy the executable to a location that is in your `PATH`.

## Commands

- `zph help` - Display the help message

- `zph version` - Display the version of zph

- `zph fetch <user>/<repo>` - Fetch the latest commits from a repository, and print the archive URL

- `zph save <user>/<repo>` - Pass the archive URL to the package manager to save the package
  - Internally, zph will use the `zig fetch` command to save the package. Note that you must be in the same directory as the `builg.zig.zon` file for this to work.

## License

zph is licensed under the MIT license. See the [LICENSE](/LICENSE) file for more information.
