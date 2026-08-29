module seali_test;
import seali;
import std::io;
import std::collections::maybe;
import std::core::test;

// ── Structs ────────────────────────────────────────────────────────────────

$expand(seali::@derive(StringLongCli));
struct StringLongCli @Command({.name = "t"}) {
    String name @Seali(arg(long, help = "name"));
}

$expand(seali::@derive(StringShortAutoCli));
struct StringShortAutoCli @Command({.name = "t"}) {
    String name @Seali(arg(short, help = "name"));
}

$expand(seali::@derive(StringShortCustomCli));
struct StringShortCustomCli @Command({.name = "t"}) {
    String name @Seali(arg(short = 'x', help = "name"));
}

$expand(seali::@derive(UintCli));
struct UintCli @Command({.name = "t"}) {
    uint count @Seali(arg(long, help = "count"));
}

$expand(seali::@derive(IntCli));
struct IntCli @Command({.name = "t"}) {
    int offset @Seali(arg(long, help = "offset"));
}

$expand(seali::@derive(BoolLongCli));
struct BoolLongCli @Command({.name = "t"}) {
    bool verbose @Seali(arg(long, default_value = false, help = "verbose"));
}

$expand(seali::@derive(BoolShortCli));
struct BoolShortCli @Command({.name = "t"}) {
    bool verbose @Seali(arg(short = 'V', default_value = false, help = "verbose"));
}

$expand(seali::@derive(DefaultsCli));
struct DefaultsCli @Command({.name = "t"}) {
    String output  @Seali(arg(long, default_value = "out.txt", help = "output file"));
    uint   threads @Seali(arg(long, default_value = 4, help = "threads"));
}

$expand(seali::@derive(MaybeStringCli));
struct MaybeStringCli @Command({.name = "t"}) {
    Maybe{String} output @Seali(arg(long, help = "output"));
}

$expand(seali::@derive(MaybeUintCli));
struct MaybeUintCli @Command({.name = "t"}) {
    Maybe{uint} count @Seali(arg(long, help = "count"));
}

$expand(seali::@derive(PositionalCli));
struct PositionalCli @Command({.name = "t"}) {
    String input @Seali(arg(help = "input file"));
}

$expand(seali::@derive(KebabCaseCli));
struct KebabCaseCli @Command({.name = "t", .rename_all = KEBAB_CASE}) {
    String input_file @Seali(arg(long, help = "input file"));
}

$expand(seali::@derive(VerbatimCli));
struct VerbatimCli @Command({.name = "t", .rename_all = VERBATIM}) {
    String input_file @Seali(arg(long, help = "input file"));
}

$expand(seali::@derive(ShortAndLongCli));
struct ShortAndLongCli @Command({.name = "t"}) {
    String name @Seali(arg(short, long, help = "name"));
}

$expand(seali::@derive(CustomLongCli));
struct CustomLongCli @Command({.name = "t"}) {
    String output @Seali(arg(long = "out", help = "output"));
}

$expand(seali::@derive(SkipCli));
struct SkipCli @Command({.name = "t"}) {
    String name     @Seali(arg(long, help = "name"));
    int    internal @Seali(arg(skip));
}

// Subcommand structs need no @derive: they are parsed through `impl_parse` from
// within the parent command.
struct SubInstall @Command({.name = "install"}) {
    String name @Seali(arg(help = "lib name"));
}

struct SubFetch @Command({.name = "fetch"}) {
    String url @Seali(arg(long, help = "url"));
}

$expand(seali::@derive(SubCli));
struct SubCli @Command({.name = "t"}) {
    Maybe{SubInstall} install @Seali(arg(subcommand));
    Maybe{SubFetch}   fetch   @Seali(arg(subcommand));
}

$expand(seali::@derive(MultiCli));
struct MultiCli @Command({.name = "t"}) {
    String name    @Seali(arg(short, long, help = "name"));
    uint   count   @Seali(arg(short, long, default_value = 1, help = "count"));
    bool   verbose @Seali(arg(short = 'V', long, default_value = false, help = "verbose"));
}

$expand(seali::@derive(PosAndFlagCli));
struct PosAndFlagCli @Command({.name = "t"}) {
    String flag       @Seali(arg(long, default_value = "default", help = "flag"));
    String positional @Seali(arg(help = "positional"));
}

$expand(seali::@derive(ShortCustomAndLongCli));
struct ShortCustomAndLongCli @Command({.name = "t"}) {
    String output @Seali(arg(short = 'o', long = "out", help = "output"));
}

$expand(seali::@derive(TwoRequiredCli));
struct TwoRequiredCli @Command({.name = "t"}) {
    String first  @Seali(arg(long, help = "first"));
    String second @Seali(arg(long, help = "second"));
}

$expand(seali::@derive(HelpOnEmptyCli));
struct HelpOnEmptyCli @Command({.name = "t", .help_on_empty = true}) {
    Maybe{String} name @Seali(arg(long, help = "name"));
}

// ── String flags ───────────────────────────────────────────────────────────

fn void test_string_long_flag() @test {
    String[] args = {"prog", "--name", "Alice"};
    StringLongCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Alice");
}

fn void test_string_short_auto_flag() @test {
    String[] args = {"prog", "-n", "Bob"};
    StringShortAutoCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Bob");
}

fn void test_string_short_custom_flag() @test {
    String[] args = {"prog", "-x", "Charlie"};
    StringShortCustomCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Charlie");
}

// ── Numeric flags ──────────────────────────────────────────────────────────

fn void test_uint_flag() @test {
    String[] args = {"prog", "--count", "42"};
    UintCli cli;
    cli.parse(args)!!;
    assert(cli.count == 42);
}

fn void test_uint_flag_zero() @test {
    String[] args = {"prog", "--count", "0"};
    UintCli cli;
    cli.parse(args)!!;
    assert(cli.count == 0);
}

fn void test_uint_flag_large() @test {
    String[] args = {"prog", "--count", "65535"};
    UintCli cli;
    cli.parse(args)!!;
    assert(cli.count == 65535);
}

fn void test_int_positive() @test {
    String[] args = {"prog", "--offset", "99"};
    IntCli cli;
    cli.parse(args)!!;
    assert(cli.offset == 99);
}

// ── Bool flags ─────────────────────────────────────────────────────────────

fn void test_bool_long_flag_sets_true() @test {
    String[] args = {"prog", "--verbose"};
    BoolLongCli cli;
    cli.parse(args)!!;
    assert(cli.verbose == true);
}

fn void test_bool_long_flag_absent_uses_default() @test {
    String[] args = {"prog"};
    BoolLongCli cli;
    cli.parse(args)!!;
    assert(cli.verbose == false);
}

fn void test_bool_short_flag_sets_true() @test {
    String[] args = {"prog", "-V"};
    BoolShortCli cli;
    cli.parse(args)!!;
    assert(cli.verbose == true);
}

fn void test_bool_short_flag_absent_uses_default() @test {
    String[] args = {"prog"};
    BoolShortCli cli;
    cli.parse(args)!!;
    assert(cli.verbose == false);
}

// ── Default values ─────────────────────────────────────────────────────────

fn void test_all_defaults_applied() @test {
    String[] args = {"prog"};
    DefaultsCli cli;
    cli.parse(args)!!;
    assert(cli.output == "out.txt");
    assert(cli.threads == 4);
}

fn void test_all_defaults_overridden() @test {
    String[] args = {"prog", "--output", "custom.txt", "--threads", "8"};
    DefaultsCli cli;
    cli.parse(args)!!;
    assert(cli.output == "custom.txt");
    assert(cli.threads == 8);
}

fn void test_partial_defaults() @test {
    String[] args = {"prog", "--threads", "2"};
    DefaultsCli cli;
    cli.parse(args)!!;
    assert(cli.output == "out.txt");
    assert(cli.threads == 2);
}

// ── Maybe{T} fields ────────────────────────────────────────────────────────

fn void test_maybe_string_present() @test {
    String[] args = {"prog", "--output", "file.txt"};
    MaybeStringCli cli;
    cli.parse(args)!!;
    assert((cli.output.get() ?? "") == "file.txt");
}

fn void test_maybe_string_absent() @test {
    String[] args = {"prog"};
    MaybeStringCli cli;
    cli.parse(args)!!;
    assert((cli.output.get() ?? "ABSENT") == "ABSENT");
}

fn void test_maybe_uint_present() @test {
    String[] args = {"prog", "--count", "7"};
    MaybeUintCli cli;
    cli.parse(args)!!;
    assert((cli.count.get() ?? 0) == 7);
}

fn void test_maybe_uint_absent() @test {
    String[] args = {"prog"};
    MaybeUintCli cli;
    cli.parse(args)!!;
    assert((cli.count.get() ?? 999) == 999);
}

// ── Positional args ────────────────────────────────────────────────────────

fn void test_positional_arg() @test {
    String[] args = {"prog", "myfile.txt"};
    PositionalCli cli;
    cli.parse(args)!!;
    assert(cli.input == "myfile.txt");
}

fn void test_positional_with_flag_before() @test {
    String[] args = {"prog", "--flag", "flagval", "posval"};
    PosAndFlagCli cli;
    cli.parse(args)!!;
    assert(cli.flag == "flagval");
    assert(cli.positional == "posval");
}

fn void test_positional_with_flag_after() @test {
    String[] args = {"prog", "posval", "--flag", "flagval"};
    PosAndFlagCli cli;
    cli.parse(args)!!;
    assert(cli.flag == "flagval");
    assert(cli.positional == "posval");
}

fn void test_positional_flag_uses_default() @test {
    String[] args = {"prog", "posval"};
    PosAndFlagCli cli;
    cli.parse(args)!!;
    assert(cli.flag == "default");
    assert(cli.positional == "posval");
}

// ── Case renaming ──────────────────────────────────────────────────────────

fn void test_kebab_case_underscore_to_dash() @test {
    String[] args = {"prog", "--input-file", "test.txt"};
    KebabCaseCli cli;
    cli.parse(args)!!;
    assert(cli.input_file == "test.txt");
}

fn void test_verbatim_preserves_underscores() @test {
    String[] args = {"prog", "--input_file", "test.txt"};
    VerbatimCli cli;
    cli.parse(args)!!;
    assert(cli.input_file == "test.txt");
}

// ── Short + long flags ─────────────────────────────────────────────────────

fn void test_both_flags_used_via_long() @test {
    String[] args = {"prog", "--name", "Alice"};
    ShortAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Alice");
}

fn void test_both_flags_used_via_long_eq() @test {
    String[] args = {"prog", "--name=Alice"};
    ShortAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Alice");
}

fn void test_both_flags_used_via_short() @test {
    String[] args = {"prog", "-n", "Bob"};
    ShortAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Bob");
}
fn void test_both_flags_used_via_short_eq() @test {
    String[] args = {"prog", "-n=Bob"};
    ShortAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Bob");
}

fn void test_custom_short_and_long_via_short() @test {
    String[] args = {"prog", "-o", "result.txt"};
    ShortCustomAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.output == "result.txt");
}

fn void test_custom_short_and_long_via_long() @test {
    String[] args = {"prog", "--out", "result.txt"};
    ShortCustomAndLongCli cli;
    cli.parse(args)!!;
    assert(cli.output == "result.txt");
}

fn void test_custom_long_name() @test {
    String[] args = {"prog", "--out", "result.txt"};
    CustomLongCli cli;
    cli.parse(args)!!;
    assert(cli.output == "result.txt");
}

// ── Skip ───────────────────────────────────────────────────────────────────

fn void test_skip_field_ignored_in_parse() @test {
    String[] args = {"prog", "--name", "Alice"};
    SkipCli cli;
    cli.parse(args)!!;
    assert(cli.name == "Alice");
    assert(cli.internal == 0);
}

// ── Subcommands ────────────────────────────────────────────────────────────

fn void test_subcommand_present_with_positional_arg() @test {
    String[] args = {"prog", "install", "mylib"};
    SubCli cli;
    cli.parse(args)!!;
    SubInstall install = cli.install.get()!!;
    assert(install.name == "mylib");
}

fn void test_subcommand_present_with_flag_arg() @test {
    String[] args = {"prog", "fetch", "--url", "https://example.com"};
    SubCli cli;
    cli.parse(args)!!;
    SubFetch f = cli.fetch.get()!!;
    assert(f.url == "https://example.com");
}

fn void test_subcommand_absent() @test {
    String[] args = {"prog"};
    SubCli cli;
    cli.parse(args)!!;
    bool install_present = false;
    if (try cli.install.get()) { install_present = true; }
    assert(!install_present);
    bool fetch_present = false;
    if (try cli.fetch.get()) { fetch_present = true; }
    assert(!fetch_present);
}

fn void test_second_subcommand_absent_when_first_used() @test {
    String[] args = {"prog", "install", "lib"};
    SubCli cli;
    cli.parse(args)!!;
    bool fetch_present = false;
    if (try cli.fetch.get()) { fetch_present = true; }
    assert(!fetch_present);
}

// ── Multi-flag commands ─────────────────────────────────────────────────────

fn void test_multi_all_flags_provided() @test {
    String[] args = {"prog", "--name", "World", "--count", "3", "-V"};
    MultiCli cli;
    cli.parse(args)!!;
    assert(cli.name == "World");
    assert(cli.count == 3);
    assert(cli.verbose == true);
}

fn void test_multi_only_required_flag_uses_defaults() @test {
    String[] args = {"prog", "--name", "World"};
    MultiCli cli;
    cli.parse(args)!!;
    assert(cli.name == "World");
    assert(cli.count == 1);
    assert(cli.verbose == false);
}

fn void test_multi_short_flags_combined_separately() @test {
    String[] args = {"prog", "-n", "World", "-c", "5"};
    MultiCli cli;
    cli.parse(args)!!;
    assert(cli.name == "World");
    assert(cli.count == 5);
    assert(cli.verbose == false);
}


enum LogLevel : (String name) {
  VERBOSE { "verbose" },
  DEBUG { "debug" },
  INFO { "information" },
  WARN { "warn" },
  ERROR { "error" },
}

$expand(seali::@derive(EnumDesCli));
struct EnumDesCli @Command({.name = "t"}) {
    LogLevel log_level @Seali(arg(long, help = "Log level"));
}

$expand(seali::@derive(EnumOrdCli));
struct EnumOrdCli @Command({.name = "t"}) {
    LogLevel log_level @Seali(arg(long, enum_as = ORDINAL, help = "Log level"));
}

$expand(seali::@derive(EnumLookupCli));
struct EnumLookupCli @Command({.name = "t"}) {
    LogLevel log_level @Seali(arg(long, enum_as = name, help = "Log level"));
}

$expand(seali::@derive(EnumDefaultCli));
struct EnumDefaultCli @Command({.name = "t"}) {
    LogLevel log_level @Seali(arg(long, default_value = WARN, help = "Log level"));
}

fn void test_enum_description() @test {
    String[] args = {"prog", "--log-level", "info"};
    EnumDesCli cli;
    cli.parse(args)!!;
    assert(cli.log_level == INFO);
}

fn void test_enum_ordinal() @test {
    String[] args = {"prog", "--log-level", "2"};
    EnumOrdCli cli;
    cli.parse(args)!!;
    assert(cli.log_level == INFO);
}

fn void test_enum_lookup() @test {
    String[] args = {"prog", "--log-level", "information"};
    EnumLookupCli cli;
    cli.parse(args)!!;
    assert(cli.log_level == INFO);
}

fn void test_enum_default_applied() @test {
    String[] args = {"prog"};
    EnumDefaultCli cli;
    cli.parse(args)!!;
    assert(cli.log_level == WARN);
}

// ── Derive ─────────────────────────────────────────────────────────────────

fn void test_derive_generates_parse_method() @test {
    StringLongCli cli;
    assert($defined(cli.parse));
}

fn void test_derive_parse_propagates_error() @test {
    String[] args = {"prog", "--log-level", "nope"};
    EnumDesCli cli;
    test::@error(cli.parse(args), seali::INVALID_ENUM_VALUE);
}

fn void test_derive_reparse_same_struct() @test {
    EnumDefaultCli cli;
    String[] first = {"prog", "--log-level", "debug"};
    cli.parse(first)!!;
    assert(cli.log_level == DEBUG);

    String[] second = {"prog", "--log-level", "error"};
    cli.parse(second)!!;
    assert(cli.log_level == ERROR);
}

// ── Faults returned by parse ───────────────────────────────────────────────
// `parse` reports every failure as a fault instead of terminating the
// program, so each of these keeps running after the call returns.

fn void test_unknown_long_option_returns_fault() @test {
    String[] args = {"prog", "--nope", "x"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::UNKNOWN_OPTION);
}

fn void test_unknown_short_option_returns_fault() @test {
    String[] args = {"prog", "-z"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::UNKNOWN_OPTION);
}

fn void test_unknown_option_with_eq_returns_fault() @test {
    String[] args = {"prog", "--nope=1"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::UNKNOWN_OPTION);
}

fn void test_missing_required_long_returns_fault() @test {
    String[] args = {"prog"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::MISSING_REQUIRED_OPTION);
}

fn void test_missing_required_positional_returns_fault() @test {
    String[] args = {"prog"};
    PositionalCli cli;
    test::@error(cli.parse(args), seali::MISSING_REQUIRED_OPTION);
}

fn void test_missing_one_of_two_required_returns_fault() @test {
    String[] args = {"prog", "--first", "a"};
    TwoRequiredCli cli;
    test::@error(cli.parse(args), seali::MISSING_REQUIRED_OPTION);
}

fn void test_missing_required_in_subcommand_returns_fault() @test {
    String[] args = {"prog", "install"};
    SubCli cli;
    test::@error(cli.parse(args), seali::MISSING_REQUIRED_OPTION);
}

fn void test_unknown_option_in_subcommand_returns_fault() @test {
    String[] args = {"prog", "fetch", "--nope"};
    SubCli cli;
    test::@error(cli.parse(args), seali::UNKNOWN_OPTION);
}

fn void test_help_long_returns_fault() @test {
    String[] args = {"prog", "--help"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::HELP_PRINTED);
}

fn void test_help_short_returns_fault() @test {
    String[] args = {"prog", "-h"};
    StringLongCli cli;
    test::@error(cli.parse(args), seali::HELP_PRINTED);
}

fn void test_help_wins_over_missing_required() @test {
    String[] args = {"prog", "--help"};
    TwoRequiredCli cli;
    test::@error(cli.parse(args), seali::HELP_PRINTED);
}

fn void test_help_on_empty_returns_fault() @test {
    String[] args = {"prog"};
    HelpOnEmptyCli cli;
    test::@error(cli.parse(args), seali::HELP_PRINTED);
}

fn void test_invalid_enum_description_returns_fault() @test {
    String[] args = {"prog", "--log-level", "nope"};
    EnumDesCli cli;
    test::@error(cli.parse(args), seali::INVALID_ENUM_VALUE);
}

fn void test_non_numeric_enum_ordinal_returns_fault() @test {
    String[] args = {"prog", "--log-level", "nope"};
    EnumOrdCli cli;
    test::@error(cli.parse(args), string::MALFORMED_INTEGER);
}

fn void test_non_numeric_uint_returns_fault() @test {
    String[] args = {"prog", "--count", "abc"};
    UintCli cli;
    test::@error(cli.parse(args), string::MALFORMED_INTEGER);
}

fn void test_negative_uint_returns_fault() @test {
    String[] args = {"prog", "--count", "-5"};
    UintCli cli;
    test::@error(cli.parse(args), string::NEGATIVE_VALUE);
}

fn void test_parse_returns_instead_of_terminating() @test {
    StringLongCli cli;

    String[] bad = {"prog", "--nope"};
    bool got_fault = false;
    if (catch f = cli.parse(bad)) {
        got_fault = true;
        assert(f == seali::UNKNOWN_OPTION);
    }
    assert(got_fault);

    // execution continues: the same struct still parses afterwards
    String[] good = {"prog", "--name", "Alice"};
    cli.parse(good)!!;
    assert(cli.name == "Alice");
}
