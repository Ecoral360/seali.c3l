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
  bool skip;
  bool is_subcommand;
}

macro ArgConfig.@is_unamed($self) {
  return $self.longn.len == 0 &&& $self.shortn == 0;
}

macro parse($Cmd, String[] _args) {
  var args = _args[1..];

  if (args.len == 0) {
    print_long_about($Cmd);
  }

  List{String} args_with_values;
  args_with_values.init(mem);
  defer args_with_values.free();

  $Cmd cmd;

  // set the default value of all the field that have one
  $foreach $member : $Cmd.membersof:
    ArgConfig $config = @setup_config($member);
    $if !$config.skip:
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
      $if @is_maybe_type($member.type):
        args_with_values.push($member.nameof);
      $endif
    $endif
  $endforeach

  List{String} got_value;
  got_value.init(mem);
  defer got_value.free();

  int i = 0;
  while (i < args.len) {
    $foreach $member : $Cmd.membersof:
      ArgConfig $config = @setup_config($member);
      $if !$config.skip:
        if (args[i] == "--help") print_long_about($Cmd);
        if (args[i] == "-h") print_short_about($Cmd);

        if (@arg_name_matches($config, $member, args[i]) && !got_value.contains($member.nameof)) {
          args_with_values.push($member.nameof);
          got_value.push($member.nameof);
          $if !$config.@is_unamed():
            i++;
          $endif
          i += @arg_set_value(cmd, $member, $config, args, i)!;
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
    ArgConfig $config = @setup_config($member);
    $if !$config.skip:
      if (!args_with_values.contains($member.nameof)) {
        if (!has_missing) {
          io::eprint("Missing required option ");
        } else {
          io::eprint(", ");
        }
        io::eprint(@get_name($config));
        has_missing = true;
      }
    $endif
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
  ArgConfig $config = $member.has_tagof("seali:arg") ??? $member.tagof("seali:arg") : {};

  char $shortn;
  String $longn;

  $if $current_config.autoshort:
    $shortn = $arg.nameof[0];
  $endif

  $if $current_config.autolong:
    $longn = $arg.nameof;
  $endif

  $if $current_config.is_subcommand:
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

macro bool @arg_name_matches(ArgConfig $config, $member, value) {
  $if $config.is_subcommand:
    var $inner = @get_maybe_inner_type($member.type);
    $if !$inner.has_tagof("seali:cmd_name"):
      $error "Subcommands must have the @Command attribute";
    $endif
    if (value == $inner.tagof("seali:cmd_name")) {
      return true;
    }
  $endif

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

  $if $config.@is_unamed():
    return true;
  $else
    return false;
  $endif
}

// returns the number of consummed values
macro int? @arg_set_value(#cmd, $arg, $config, args, i) {
  var val = @arg_to_value($arg.type, args, i);
  $if $defined(val!):
    if (catch val) {
      val!;
      return 0;
    }
  $endif
  #cmd.$eval($arg.nameof) = val;
  $switch:
    $case $arg.type == bool:
      return 1;

    $case @is_maybe_type($arg.type):
      return args.len;

    $case $arg.type.has_tagof("seali:cmd_name"):
      return args.len;

    $default:
      return 1;
  $endswitch

}

macro @arg_to_value($Type, args, i) {
  $if @is_maybe_type($Type):
    $Type $t;
    return maybe::value{$typeof($t.value)}(@arg_to_value($typeof($t.value), args, i));
  $endif
  
  $switch:
    $case $Type == bool:
      return true;

    $case $Type == int:
      String arg = args[i];
      return arg.to_int()!;

    $case $Type == uint:
      String arg = args[i];
      return arg.to_uint()!;

    $case $Type == String:
      return args[i];

    $case $Type.has_tagof("seali:cmd_name"):
      // if (i - 1 >= args.len) {
      //   return parse($Type, {args[^2]})!;
      // } else {
        return parse($Type, args[i - 1..])!;
      // }

    // $default:
    //   $error "Unsupported type arg '" +++ $Type.nameof +++ "'";
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

  var $has_subcommands = false;
  $foreach $member : $Cmd.membersof :
    $if $member.has_tagof("seali:arg"):
      $if $member.tagof("seali:arg").is_subcommand:
        $has_subcommands = true;
      $endif
    $endif
  $endforeach

  io::print(@sprintf("Usage %s", $name));
  $if @has_options_args($Cmd):
    io::print(" [OPTIONS]");
  $endif

  @print_required_args($Cmd);

  $if $has_subcommands:
    io::print(" <COMMANDS>");
    io::printn("\n");
    io::printn("Commands:");
    @print_subcommands($Cmd);
    io::printn();
  $else
    io::printn("\n");
  $endif
  $if @has_options_args($Cmd):
    io::printn("Options:");
    @print_all_args($Cmd);
  $endif

  io::printn();
  libc::exit(0);
}

macro print_short_about($Cmd) @private {
  print_long_about($Cmd);
}

macro @print_subcommands($Cmd) @private {
  var $max_len = 0;
  $foreach $member : $Cmd.membersof :
    ArgConfig $config = @setup_config($member);
    $if $config.is_subcommand:
      var $inner = @get_maybe_inner_type($member.type);
      $if !$inner.has_tagof("seali:cmd_name"):
        $error "Subcommands must have the @Command attribute";
      $endif
      var $name = $inner.tagof("seali:cmd_name");
      $if $name.len > $max_len:
        $max_len = $name.len;
      $endif
    $endif
  $endforeach

  $foreach $member : $Cmd.membersof :
    ArgConfig $config = @setup_config($member);
    $if $config.is_subcommand:
      var $inner = @get_maybe_inner_type($member.type);
      $if !$inner.has_tagof("seali:cmd_name"):
        $error "Subcommands must have the @Command attribute";
      $endif
      var $name = $inner.tagof("seali:cmd_name");
      io::print(" " +++ $name);
      $for var $i = $name.len; $i < $max_len + 2; $i++:
        io::print(" ");
      $endfor
      $switch: 
        $case $inner.has_tagof("seali:long_about"):
          io::printn($inner.tagof("seali::long_about"));

        $case $inner.has_tagof("seali:about"):
          io::printn($inner.tagof("seali:about"));

      $endswitch
    $endif
  $endforeach
}

macro @has_options_args($Cmd) @private {
  var $has_required = false;
  $foreach $member : $Cmd.membersof :
    ArgConfig $config = @setup_config($member);
    $if !$config.is_subcommand &&& ($config.default_value.len > 0 ||| @is_maybe_type($member.type)):
      return true;
    $endif
  $endforeach
  return false;
}

macro @print_required_args($Cmd) @private {
  $foreach $member : $Cmd.membersof :
    ArgConfig $config = @setup_config($member);
    $if $config.default_value.len == 0 &&& !@is_maybe_type($member.type):
      var $name = @get_name($config);
      $if $name.len > 0:
        io::print(" " +++ $name);
      $endif
      io::print(@sprintf(" <%s>", $member.nameof.@to_upper()));
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
    ArgConfig $config = @setup_config($member);
    $if !$config.is_subcommand &&& ($config.default_value.len != 0 ||| @is_maybe_type($member.type)):
      var $all_names = @get_all_names($config);
      $if $all_names.len > 0:
        var $member_len = $all_names.len + @arg_value_to_string($member).len + 2; // 2 spaces
        $if $member_len > $max_len:
          $max_len = $member_len;
        $endif
      $endif
    $endif
  $endforeach

  $foreach $member : $Cmd.membersof :
    ArgConfig $config = @setup_config($member);
    $if !$config.is_subcommand &&& ($config.default_value.len != 0 ||| @is_maybe_type($member.type)):
      var $all_names = @get_all_names($config);
      $if $all_names.len > 0:
        var $arg_value = @arg_value_to_string($member);
        io::print(@sprintf(" %s", $all_names));
        io::print(@sprintf(" %s", $arg_value));
        $for var $i = $all_names.len + $arg_value.len + 2; $i < $max_len + 1; $i++:
          io::print(" ");
        $endfor
        @print_arg_desc($config);
        io::printn();
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




macro @get_maybe_inner_type($Type) {
  $if @is_maybe_type($Type):
    $Type $t;
    return @get_maybe_inner_type($typeof($t.value));
  $endif
  return $Type;
}






















