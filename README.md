# seali

A lightweight CLI library for C3 that makes writing command-line interfaces simple and declarative using macros and attributes.

## Features

- **Declarative CLI definition** - Define your CLI using structs and attributes
- **Automatic help generation** - Built-in `-h`/`--help` with formatted output
- **Short and long flags** - Support for both `-f` and `--flag` style arguments
- **Default values** - Optional arguments with fallback values
- **Optional arguments** - Use `Maybe{T}` for arguments that may not be provided
- **Subcommands** - Nest command structs for multi-command CLIs
- **Positional arguments** - Fields without a flag name are matched positionally
- **Enum arguments** - Match by constant name, ordinal, or an associated-value field
- **Compact codegen** - `seali::@derive` emits one `parse` function per command instead of inlining the parser at each call site

## Installation

### Using [c3l](https://github.com/konimarti/c3l):

```sh
c3l fetch https://github.com/Ecoral360/seali.c3l
```

### Manually

1. Make sure you have the [C3 compiler installed](https://github.com/c3lang/c3)
2. Run `c3c init <YOUR_PROJECT>`
3. Clone this repository into `<YOUR_PROJECT>/lib/seali.c3l`
4. Add `"dependencies": ["seali"]` to your `project.json`

## Quick Start

```c3
module myapp;

import std::io;
import seali;

$expand(seali::@derive(Cli));
struct Cli @Command({.name = "greet", .about = "Simple program to greet a person"})
{
  String name  @Seali(arg(short, long, help = "Your name"));
  uint   count @Seali(arg(short, long, default_value = 1, help = "Number of times to greet"));
}

fn int main(String[] args) {
  Cli cli;
  cli.parse(args)!!;

  for (uint i = 0; i < cli.count; i++) {
    io::printfn("Hello, %s!", cli.name);
  }

  return 0;
}
```

```bash
./build/myapp --name World
# Output: Hello, World!
```

The `$expand(seali::@derive(Cli));` line generates `fn void? Cli.parse(&self, String[] args)` for
the struct declared right below it. It must sit at file scope, and one is needed per top-level
command struct.

## Attribute Reference

### Command-Level Attribute: `@Command(CommandConfig)`

`@Command` takes a `CommandConfig` struct literal. All fields are optional except `.name`.

| Field | Description | Example |
|-------|-------------|---------|
| `.name` | Command name shown in help and matched for subcommands | `{.name = "myapp"}` |
| `.about` | Short description shown in help | `{.about = "My CLI app"}` |
| `.long_about` | Long description shown with `--help` | `{.long_about = "A longer description..."}` |
| `.version` | Version string | `{.version = "1.0.0"}` |
| `.help_on_empty` | Show help when invoked with no arguments | `{.help_on_empty = true}` |
| `.rename_all` | Convention for auto-generated long flag names | `{.rename_all = KEBAB_CASE}` |

`CaseConvention` values: `KEBAB_CASE` (default), `VERBATIM`.

### Field-Level Attribute: `@Seali(arg(...))`

All field configuration goes through the `@Seali(arg(...))` attribute. The `arg` macro accepts the following named options:

| Option | Description | Example |
|--------|-------------|---------|
| `short` | Auto-generate short flag from the first character of the field name | `arg(short)` |
| `short = 'X'` | Custom short flag | `arg(short = 'n')` |
| `long` | Auto-generate long flag from the field name | `arg(long)` |
| `long = "name"` | Custom long flag | `arg(long = "output")` |
| `default_value = val` | Makes the field optional with a fallback | `arg(default_value = 4)` |
| `enum_as = mode` | How an enum field matches its argument — see [Enum arguments](#enum-arguments) | `arg(enum_as = ORDINAL)` |
| `help = "text"` | Description shown in `--help` output | `arg(help = "Input file")` |
| `subcommand` | Marks a `Maybe{SubCmd}` field as a subcommand | `arg(subcommand)` |
| `skip` | Exclude this field from CLI parsing entirely | `arg(skip)` |

Options can be combined:

```c3
String output @Seali(arg(short, long = "out", help = "Output file", default_value = "a.out"));
```

### Argument Kinds

| Kind | How to declare | Required? |
|------|---------------|-----------|
| Required flag | `arg(long)` with no `default_value` | Yes |
| Optional flag | `arg(long, default_value = val)` | No (uses default) |
| Optional (no default) | Field type is `Maybe{T}` | No (absent = `none`) |
| Positional | No `short`/`long` and no `default_value` | Yes |
| Subcommand | `Maybe{SubCmd}` + `arg(subcommand)` | No |

## Examples

### Flags with defaults

```c3
$expand(seali::@derive(Cli));
struct Cli @Command({.name = "myapp", .about = "My awesome CLI application"})
{
  String input_file @Seali(arg(short, long, help = "Input file path"));
  bool   verbose    @Seali(arg(short = 'V', long, default_value = false, help = "Enable verbose output"));
  String output     @Seali(arg(short, long = "out", help = "Output file", default_value = "out.txt"));
  uint   threads    @Seali(arg(short, default_value = 4, help = "Number of threads"));
}

fn int main(String[] args) {
  Cli cli;
  cli.parse(args)!!;

  if (cli.verbose) {
    io::printfn("Processing %s with %d threads", cli.input_file, cli.threads);
  }

  return 0;
}
```

```bash
./build/myapp --help
```

```
My awesome CLI application

Usage myapp [OPTIONS] --input-file <INPUT_FILE>

Options:
 -i, --input-file <INPUT_FILE>  Input file path
 -V, --verbose                  Enable verbose output [default: false]
 -o, --out <OUTPUT>             Output file [default: "out.txt"]
 -t <THREADS>                   Number of threads [default: 4]
```

Note that `<VALUE>` placeholders come from the **field** name, not the flag name, and
`[default: ...]` echoes the default exactly as it was written in the attribute.

### Subcommands

Use a `Maybe{SubCmd}` field with `arg(subcommand)` to define subcommands. Each subcommand is its own struct marked with `@Command`.

```c3
$expand(seali::@derive(Cli));
struct Cli @Command({.name = "myapp", .about = "My package manager"})
{
  Maybe{Install} install @Seali(arg(subcommand));
  Maybe{Fetch}   fetch   @Seali(arg(subcommand));
}

struct Install @Command({.name = "install", .about = "Install a library"})
{
  String name @Seali(arg(help = "The library to install"));
}

struct Fetch @Command({.name = "fetch", .about = "Fetch a tar file"})
{
  String url @Seali(arg(help = "The URL to fetch"));
}

fn int main(String[] args) {
  Cli cli;
  cli.parse(args)!!;

  if (try install = cli.install.get()) {
    io::printfn("Installing: %s", install.name);
  }
  if (try fetch = cli.fetch.get()) {
    io::printfn("Fetching: %s", fetch.url);
  }

  return 0;
}
```

```bash
./build/myapp install mylib
# Output: Installing: mylib
```

Only the top-level command needs `seali::@derive`. Subcommand structs are parsed from within their
parent, so `Install` and `Fetch` above get no `.parse` method of their own.

### Enum arguments

Enum-typed fields are supported natively. `enum_as` picks how the argument string is matched:

| `enum_as` | Matches on | Example |
|-----------|------------|---------|
| omitted, or `DESCRIPTION` | the enum constant name, case-insensitive | `--level info` → `INFO` |
| `ORDINAL` | the constant's ordinal | `--level 2` → `INFO` |
| a lowercase identifier | that associated-value field | `enum_as = name` + `--level information` → `INFO` |

```c3
enum LogLevel : (String name) {
  VERBOSE { "verbose" },
  DEBUG   { "debug" },
  INFO    { "information" },
  WARN    { "warn" },
  ERROR   { "error" },
}

$expand(seali::@derive(Cli));
struct Cli @Command({.name = "myapp"})
{
  LogLevel level    @Seali(arg(long, help = "Log level", default_value = WARN));
  LogLevel ordinal  @Seali(arg(long, help = "Log level", enum_as = ORDINAL));
  LogLevel by_field @Seali(arg(long, help = "Log level", enum_as = name));
}
```

An enum `default_value` is written **bare, without the type prefix** — `default_value = WARN`, not
`default_value = LogLevel.WARN`. Anything else is a compile-time error.

The accepted values are listed automatically in the help output:

```
Usage myapp [OPTIONS] --ordinal <ORDINAL> --by-field <BY_FIELD>

Options:
 --level <LEVEL>        Log level {values: verbose | debug | info | warn | error} [default: WARN]
 --ordinal <ORDINAL>    Log level {values: 0..4}
 --by-field <BY_FIELD>  Log level {values: verbose | debug | information | warn | error}
```

A value that matches no constant makes `parse` return `seali::INVALID_ENUM_VALUE`.

## API

### `$expand(seali::@derive($Cmd));`

Generates

```c3
fn void? $Cmd.parse(&self, String[] args)
```

for the given command struct. Place it at file scope, directly above the struct it derives; one per
top-level command.

The generated method parses `args` into `self` **in place**: it writes the fields it finds, applies
defaults for the ones it doesn't, and leaves `arg(skip)` fields untouched. Declare the struct
without an initializer so the untouched fields stay zeroed.

```c3
Cli cli;
cli.parse(args)!!;
```

It handles `-h`/`--help`, validates required fields, and exits the process on an unknown or missing
option. It returns an optional for value-level failures (a malformed number, an unknown enum value)
— use `!!` to panic or `!` to propagate.

**Supported field types:** `String`, `int`, `uint`, `char`, `bool`, any enum, `Maybe{T}`, and any
struct tagged with `@Command` (for subcommands).

The older `$expand(derive($Cmd::name, seali));` spelling, going through the generic `derive` module
in `src/derive.c3`, still works and produces the same method. `seali::@derive` is preferred.

## Project Structure

```
seali.c3l/
├── src/
│   ├── curse.c3     # @Seali / arg attribute and config builder
│   ├── derive.c3    # seali::@derive - generates the `parse` method
│   ├── macros.c3    # Core parse implementation and help generation
│   ├── utils.c3     # Utility functions
│   └── main.c3      # Example usage (dev target only)
├── test/
│   └── test.c3      # Test suite (c3c test)
├── project.json
└── README.md
```

## Requirements

- C3 compiler (c3c)
- C3 standard library

## License

MIT License
