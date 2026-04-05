module seali;
import libc;
import std::io;
import std::collections::list;
import std::collections::maybe;

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
  bool autoshort;
  String longn;
  bool autolong;
  String help;
  String long_help;
  String default_value;
  String env;
}

macro parse($Cmd, String[] _args) {
  var args = _args[1..];

  foreach (arg: args) {
    if (arg == "--help") print_long_about($Cmd);
    if (arg == "-h") print_short_about($Cmd);
  }

  List{String} args_with_values;
  args_with_values.init(mem);
  defer args_with_values.free();

  $Cmd cmd;

  // set the default value of all the field that have one
  $foreach $member : $Cmd.membersof:
    $if $member.has_tagof("seali:arg"):
      ArgConfig $config = $member.tagof("seali:arg");
      $if $config.default_value.len > 0:
        args_with_values.push($member.nameof);
        do {
          var val = @str_to_value($member.type, $config.default_value);
          $if $defined(val!):
            if (catch val) {
              val!;
              return cmd;
            }
          $endif
          cmd.$eval($member.nameof) = val;
        };
      $endif
    $endif
    $if @is_maybe_type($member.type):
      args_with_values.push($member.nameof);
    $endif
  $endforeach

  int i = 0;
  while (i < args.len) {
    $foreach $member : $Cmd.membersof:
      $if $member.has_tagof("seali:arg"):
        ArgConfig $config = @setup_config($member);
        if (@arg_name_matches($config, args[i])) {
          args_with_values.push($member.nameof);
          i++;
          i += @arg_set_value(cmd, $member, args, i)!;
          continue;
        }
      $endif
    $endforeach

    io::eprintfn("Unknown option '%s'\n", args[i]);
    libc::exit(-1);
  }

  var has_missing = false;
  // check that each field has been initialized
  $foreach $member : $Cmd.membersof:
    if (!args_with_values.contains($member.nameof)) {
      if (!has_missing) {
        io::eprint("Missing required option ");
      } else {
        io::eprint(", ");
      }
      $if $member.has_tagof("seali:arg"):
        ArgConfig $config = @setup_config($member);
        io::eprint(@get_name($config));
      $else
        $error @sprintf("Arg '%s' with no config missing", $member.nameof);
      $endif
      has_missing = true;
    }
  $endforeach

  if (has_missing) {
    io::eprintn();
    libc::exit(-1);
  }

  return cmd;
}

<*
  @require $arg.has_tagof("seali:arg")
*>
macro ArgConfig @setup_config($arg) {
  ArgConfig $current_config = $arg.tagof("seali:arg");

  char $shortn;
  String $longn;

  $if $current_config.autoshort:
    $shortn = $arg.nameof[0];
  $endif

  $if $current_config.autolong:
    $longn = $arg.nameof;
  $endif

  return {
    ...$current_config,
    .shortn = $shortn,
    .longn = $longn,
  };
}

macro @str_to_value($Type, #value) {
  $if @is_maybe_type($Type):
    $Type $t;
    return maybe::value{$typeof($t.value)}(@str_to_value($typeof($t.value), #value));
  $endif

  $switch:
    $case $Type == int:
      return #value.to_int();
    $case $Type == uint:
      return #value.to_uint();
    $case $Type == String:
      return #value;
    $case $Type == bool:
      return #value == "true";

    $default:
      $error "Unsupported type '" +++ $Type.nameof +++ "'";
  $endswitch
}

macro bool @arg_name_matches(ArgConfig $config, value) {
  $if $config.shortn != 0:
    if (value == ("-" +++ $config.shortn)) {
      return true;
    }
  $endif

  $if $config.longn.len > 0:
    if (value == ("--" +++ $config.longn)) {
      return true;
    }
  $endif

  return false;
}

// returns the number of consummed values
macro int? @arg_set_value(#cmd, $arg, args, i) {
  $switch:
    $case $arg.type == bool:
      #cmd.$eval($arg.nameof) = true;
      return 0;

    $case $arg.type == int:
      String arg = args[i];
      #cmd.$eval($arg.nameof) = arg.to_int()!;
      return 1;

    $case $arg.type == uint:
      String arg = args[i];
      #cmd.$eval($arg.nameof) = arg.to_uint()!;
      return 1;

    $case $arg.type == String:
      #cmd.$eval($arg.nameof) = args[i];
      return 1;

    $default:
      $error "Unsupported type arg";
  $endswitch
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
    $if $member.has_tagof("seali:arg"):
      ArgConfig $config = @setup_config($member);
      $if $config.default_value.len == 0 &&& !@is_maybe_type($member.type):
        var $name = @get_name($config);
        $if $name.len > 0:
          io::print(" " +++ $name);
        $endif
        io::print(@sprintf(" <%s>", $member.nameof.@to_upper()));
      $endif
    $endif
  $endforeach
}

macro @get_name(ArgConfig $config) @private {
  $switch:
    $case $config.longn.len > 0:
      return @sprintf("--%s", $config.longn);
    $case $config.shortn != 0:
      return "-" +++ $config.shortn;
    $default:
      return "";
  $endswitch
}

macro @print_all_args($Cmd) @private {
  var $max_len = 0;
  $foreach $member : $Cmd.membersof :
    $if $member.has_tagof("seali:arg"):
      ArgConfig $config = @setup_config($member);
      $if $config.default_value.len != 0 ||| @is_maybe_type($member.type):
        var $all_names = @get_all_names($config);
        $if $all_names.len > 0:
          var $member_len = $all_names.len + @arg_value_to_string($member).len + 2; // 2 spaces
          $if $member_len > $max_len:
            $max_len = $member_len;
          $endif
        $endif
      $endif
    $endif
  $endforeach

  $foreach $member : $Cmd.membersof :
    $if $member.has_tagof("seali:arg"):
      ArgConfig $config = @setup_config($member);
      $if $config.default_value.len != 0 ||| @is_maybe_type($member.type):
        var $all_names = @get_all_names($config);
        $if $all_names.len > 0:
          var $arg_value = @arg_value_to_string($member);
          io::print(@sprintf(" %s", $all_names));
          io::print(@sprintf(" %s", $arg_value));
          $for var $i = $all_names.len + $arg_value.len + 2; $i < $max_len; $i++:
            io::print(" ");
          $endfor
          @print_arg_desc($config);
          io::printn();
        $endif
      $endif
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

macro @print_arg_desc(ArgConfig $config) {
  $if $config.help.len > 0:
    io::printf(@sprintf(" %s", $config.help));
  $endif

  $if $config.default_value.len > 0:
    io::printf(@sprintf(" [default: %s]", $config.default_value));
  $endif
}

macro @get_all_names(ArgConfig $config) @private {
  var $result = "";
  $if $config.shortn != 0:
    $result +++= "-";
    $result +++= $config.shortn;
  $endif

  $if $config.longn.len > 0:
    $if $result.len > 0:
      $result +++= ", ";
    $endif
    $result +++= @sprintf("--%s", $config.longn);
  $endif

  return $result;
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


























