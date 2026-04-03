# seali 🌊

A lightweight CLI library for C3 that makes writing command-line interfaces simple and declarative using macros and attributes.

## Features

- **Declarative CLI definition** - Define your CLI using structs and attributes
- **Automatic help generation** - Built-in support for `-h`, `--help` with formatted output
- **Case conversion** - Automatically convert field names to different conventions (kebab-case, camelCase, PascalCase, snake_case, SCREAMING_SNAKE_CASE)
- **Default values** - Support for default values on arguments
- **Short and long flags** - Support for both `-f` and `--flag` style arguments
- **Environment variable support** - Read values from environment variables

## Installation

### Using [c3l](https://github.com/konimarti/c3l) :

Run
```sh
c3l fetch https://github.com/Ecoral360/seali.c3l
```


### Manually
Get started with `seali`: 
1. Make sure you have the [C3 compiler installed](https://github.com/c3lang/c3c)
2. Run `c3c init <YOUR_PROJECT>`
4. Clone the this repository into `<YOUR_PROJECT>/lib/seali.c3l`
5. Add `"dependencies": ["seali"]` to your `project.json`
6. You are done !

## Quick Start

```c3
module myapp;

import std::io;
import seali;

struct Cli @Command("greet") 
  @About("Simple program to greet a person")
  @RenameAll(KEBAB_CASE)
{
  String name @Short @Long @Help("Your name");
  uint count @Short @Long @Default(1) @Help("Number of times to greet");
}

fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args);
  
  for (uint i = 0; i < cli.count; i++) {
    io::printfn("Hello, %s!", cli.name);
  }
  
  return 0;
}
```

Run with:
```bash
./build/seali greet --name World
# Output: Hello, World!
```

## Attribute Reference

### Command-Level Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `@Command(String)` | Marks a struct as a CLI command | `@Command("myapp")` |
| `@About(String)` | Short description | `@About("My CLI app")` |
| `@LongAbout(String)` | Long description | `@LongAbout("A longer description...")` |
| `@RenameAll(CaseConvention)` | Convert field names | `@RenameAll(KEBAB_CASE)` |

### Case Conventions

- `KEBAB_CASE` → `my-field`
- `CAMEL_CASE` → `myField`
- `PASCAL_CASE` → `MyField`
- `SNAKE_CASE` → `my_field`
- `SCREAMING_SNAKE_CASE` → `MY_FIELD`
- `LOWER_CASE` → `myfield`
- `UPPER_CASE` → `MYFIELD`
- `VERBATIM` → Use as-is

### Field-Level Attributes

| Attribute | Description | Example |
|-----------|-------------|---------|
| `@Short` | Auto-generate short flag from first char | `@Short` |
| `@ShortName(char)` | Custom short flag | `@ShortName('n')` |
| `@Long` | Auto-generate long flag from field name | `@Long` |
| `@LongName(String)` | Custom long flag | `@LongName("name")` |
| `@Default(value)` | Default value | `@Default(1)` |
| `@Help(String)` | Help text | `@Help("Your name")` |
| `@Skip` | Skip this field in CLI | `@Skip` |

## API

### `seali::parse($Cmd, String[] args)`

Parses command-line arguments into the given command struct.

```c3
Cli cli = seali::parse(Cli, args);
```

The parse macro automatically:
- Handles `-h` and `--help` flags
- Applies default values
- Handles case conversion based on `@RenameAll`

## Example

### Full Example

```c3
module myapp;

import std::io;

struct Cli @Command("myapp") 
  @About("My awesome CLI application")
  @RenameAll(KEBAB_CASE)
{
  String input_file @Short @Long @Help("Input file path");
  bool verbose @Short @Long @Default(false) @Help("Enable verbose output");
  String output @Short @LongName("output") @Help("Output file");
  uint threads @Short @Default(4) @Help("Number of threads");
}

fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args);
  
  if (cli.verbose) {
    io::printfn("Processing %s with %d threads", cli.input_file, cli.threads);
  }
  
  // ... your logic here
  
  return 0;
}
```

### Running the above:

```bash
./build/myapp --help
```

Outputs:
```
My awesome CLI application

Usage myapp [OPTIONS] <INPUT_FILE> <OUTPUT>

Options:
 -i, --input-file <INPUT_FILE>  Input file path
 -o, --output <OUTPUT>          Output file
 -v, --verbose [default: false]  Enable verbose output
 -t, --threads <THREADS>       [default: 4] Number of threads

```

## Project Structure

```
seali.c3l/
├── src/
│   ├── main.c3       # Example usage
│   ├── macros.c3    # Core parsing macros
│   ├── cmd.c3       # Command definitions
│   └── utils.c3     # Utility functions
├── project.json      # Project configuration
└── README.md         # This file
```

## Requirements

- C3 compiler (c3c)
- C3 standard library

## License

MIT License
