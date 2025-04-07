# Up
## About
Wrote this for fun and thought it was interesting enough to make it public\
Moves the contents of a directory up one level, for an example see `tests/small/`\
I want to keep improving this, it works pretty well for a scrappy weekend project, but I want to add a lot more
## Building
No external libraries or dependencies required except for `NASM` and `ld` for building, run the provided `build.sh` for an elf64 binary\
To build with dwarf debug info run `build.sh debug`\
## Todo
 - Improve error reporting (Currently just exits without any message and without undoing anything)
 - Improve handling of symlinks
 - Improve memory management
 - Improve comments
