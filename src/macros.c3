module seali;
import libc;
import std::io;

struct CommandConfig {
  String name;
  String version;
  String about;
  String long_about;
}

attrdef @Command(String name) = @tag("seali:cmd_name", name);

attrdef @About(String about) = @tag("seali:about", about);
attrdef @LongAbout(String long_about) = @tag("seali:long_about", long_about);

enum CaseConvention : (String example) {
  KEBAB_CASE { "kebab-case" },
  CAMEL_CASE { "camelCase" },
  PASCAL_CASE { "PascalCase" },
  SCREAMING_SNAKE_CASE { "SCREAMING_SNAKE_CASE" },
  SNAKE_CASE { "snake_case" },
  LOWER_CASE { "lower" },
  UPPER_CASE { "upper" },
  VERBATIM { "verbatim" },
}

attrdef @RenameAll(CaseConvention convention) = @tag("seali:rename_all", convention);

// ------------------------------------

struct ArgConfig {
  char shortn;
  String longn;
  String help;
  String long_help;
  String default_value;
  String env;
}
/*
  @require $typeof(value) == bool ||| $typeof(value) == char
*/
attrdef @ShortName(char value) = @tag("seali:short", value);
attrdef @Short = @tag("seali:short", true);

attrdef @LongName(String value) = @tag("seali:long", value);
attrdef @Long = @tag("seali:long", true);

attrdef @Default(value) = @tag("seali:default", value);

attrdef @Skip = @tag("seali:skip", true);

attrdef @Help(String value) = @tag("seali:help", value);



struct Cli2 @Command("demo") @RenameAll(PASCAL_CASE)
{
  String name @Short @Long;

  uint count @Short @Long @Default(1) @Help("The number of times to greet");
}

macro parse($Cmd, String[] args) {
  foreach (arg: args) {
    if (arg == "--help") print_long_about($Cmd);
    if (arg == "-h") print_short_about($Cmd);
  }

  return ($Cmd) {};
}

macro print_long_about($Cmd) @private {
  $if !$Cmd.has_tagof("seali:cmd_name"):
    $error "Commands must be marked with the @Command tag";
  $endif

  var $name = $Cmd.tagof("seali:cmd_name");

  $switch: 
    $case $Cmd.has_tagof("seali:long_about"):
      io::printn($Cmd.tagof("seali::long_about") +++ "\n");

    $case $Cmd.has_tagof("seali:about"):
      io::printn($Cmd.tagof("seali:about") +++ "\n");

  $endswitch

  io::print(@sprintf("Usage %s [OPTIONS]", $name));
  @print_required_args($Cmd);
  io::printn("\n\nOptions:");
  @print_all_args($Cmd);

  io::printn();
  libc::exit(0);
}

macro print_short_about($Cmd) @private {
  print_long_about($Cmd);
}

macro @print_required_args($Cmd) @private {
  $foreach $member : $Cmd.membersof :
    $if !$member.has_tagof("seali:default") &&& !($member.has_tagof("seali:skip") &&& $member.tagof("seali:skip")) &&& !@is_maybe_type($member.type):
      var $name = @get_name($member);
      $if $name.len > 0:
        io::print(" " +++ $name);
      $endif
      io::print(@sprintf(" <%s>", $member.nameof.@to_upper()));
    $endif
  $endforeach
}

macro @get_name($member) @private {
  $switch:
    $case $member.has_tagof("seali:long"):
      return @sprintf("--%s", $typeof($member.tagof("seali:long")) == bool ??? $member.nameof : $member.tagof("seali:long"));
    $case $member.has_tagof("seali:short"):
      return "-" +++ $typeof($member.tagof("seali:short")) == bool ??? $member.nameof[0..0] : $member.tagof("seali:short");
    $default:
      return "";
  $endswitch
}

macro @print_all_args($Cmd) @private {
  var $max_len = 0;
  $foreach $member : $Cmd.membersof :
    var $all_names = @get_all_names($member);
    $if $all_names.len > 0:
      var $member_len = $all_names.len + @arg_value_to_string($member).len + 2; // 2 spaces
      $if $member_len > $max_len:
        $max_len = $member_len;
      $endif
    $endif
  $endforeach

  $foreach $member : $Cmd.membersof :
    var $all_names = @get_all_names($member);
    $if $all_names.len > 0:
      var $arg_value = @arg_value_to_string($member);
      io::print(@sprintf(" %s", $all_names));
      io::print(@sprintf(" %s", $arg_value));
      $for var $i = $all_names.len + $arg_value.len + 2; $i < $max_len; $i++:
        io::print(" ");
      $endfor
      @print_arg_desc($member);
      io::printn();
    $endif
  $endforeach
}

macro @arg_value_to_string($arg) {
  $switch:
    $case $arg.type == bool:
      return "";

    $default:
      return @sprintf("<%s>", $arg.nameof.@to_upper());
  $endswitch
}

macro @print_arg_desc($arg) {
  $if $arg.has_tagof("seali:help"):
    io::printf(@sprintf(" %s", $arg.tagof("seali:help")));
  $endif

  $if $arg.has_tagof("seali:default"):
    io::printf(@sprintf(" [default: %s]", $arg.tagof("seali:default")));
  $endif
}

macro @get_all_names($member) @private {
  var $result = "";
  $if $member.has_tagof("seali:short"):
    $result +++= "-";
    $result +++= $typeof($member.tagof("seali:short")) == bool ??? $member.nameof[0..0] : $member.tagof("seali:short");
  $endif

  $if $member.has_tagof("seali:long"):
    $if $result.len > 0:
      $result +++= ", ";
    $endif
    $result +++= @sprintf("--%s", $typeof($member.tagof("seali:long")) == bool ??? $member.nameof : $member.tagof("seali:long"));
  $endif

  return $result;
}

macro @print_arg_help($Cmd) @private {
  libc::exit(0);
}

macro parse_cmd() @private {
  var $allowed_tags = { "cmd_name", "version", "about", "long_about", "rename_all" };
}

macro parse_arg() @private {
  var $allowed_tags = { "short", "long", "default", "help" };
}



macro @is_maybe($value) {
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$typeof($value.value)}($value.value))));
}

macro @is_maybe_type($Type) {
  $Type $value;
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$typeof($value.value)}($value.value))));
}









































