<*
  The seali lib
*>
module seali;
import std::thread;
import std::io;
import std::collections::list;
import std::collections::maybe;

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

struct CommandConfig {
  String name;
  String version;
  String about;
  String long_about;
  bool help_on_empty;
  CaseConvention rename_all;
}

attrdef @Command(CommandConfig config) = @tag("seali:command", config);

// ------------------------------------

enum EnumValType {
  DESCRIPTION,
  ORDINAL,
  FIELD
}

struct EnumVal {
  EnumValType type;
  String field;
}

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
  EnumVal enum_as;
}

faultdef INVALID_ENUM_VALUE, HELP_PRINTED, UNKNOWN_OPTION, MISSING_REQUIRED_OPTION;

macro ArgConfig.@is_unamed($self) {
  return $self.longn.len == 0 &&& $self.shortn == 0;
}

fn void? impl_parse(Allocator allocator, Cmd* cmd, String[] _args) <Cmd> => @pool() {
  String[] args = _args[1..];

  if (args.len == 0 && Cmd::get_tag("seali:command").help_on_empty) {
    print_long_about{Cmd}()!;
  }

  List{String} args_with_values;
  args_with_values.tinit();

  List{String} got_value;
  got_value.tinit();

  int i = 0;
  while (i < args.len) {
    if (args[i] == "--help") print_long_about{Cmd}()!;
    if (args[i] == "-h") print_short_about{Cmd}()!;

    String name = args[i];
    bool eq_syntax = false;
    if (try eq_idx = args[i].index_of("=")) {
      name = args[i][..eq_idx - 1];
      args[i] = args[i][eq_idx + 1..args[i].len-1];
      eq_syntax = true;
    } else if (args[i].len > 2 && args[i][0] == '-' && args[i][1] != '-') {
      name = args[i][..1];
      args[i] = args[i][2..args[i].len-1];
      eq_syntax = true;
    }

    $foreach $member : Cmd::members:
      ArgConfig $config = @setup_config(Cmd::get_tag("seali:command"), $member);
      $if !$config.skip:
        var $repeatable = $member.type.is_generic(List);
        if (@arg_name_matches($config, $member, name) && ($repeatable || !got_value.contains($member.name))) {
          args_with_values.push($member.name);
          got_value.push($member.name);
          $if !($config.@is_unamed() ||| $member.type == bool):
            if (!eq_syntax) i++;
          $endif
          i += @arg_set_value(allocator, cmd, $member, $config, args, i)!;
          continue;
        }
      $endif
    $endforeach

    io::eprintfn("Unknown option '%s'\n", args[i]);
    return UNKNOWN_OPTION~;
  }

  List{String} missing;
  missing.tinit();

  // check that each field has been initialized
  $foreach $member : Cmd::members:
    ArgConfig $config = @setup_config(Cmd::get_tag("seali:command"), $member);
    $if !$config.skip:
      if (!args_with_values.contains($member.name)) {
        $switch: 
          $case $config.default_value.len > 0:
            do {
              $if $member.type.kind == ENUM:
                $if $config.default_value[0] == '"' ||| !$defined($Typefrom($member.type).$eval($config.default_value)):
                  $error @sprintf("The default value of an enum member must be the member's description without the type (found %s).", $config.default_value);
                $endif
                var val @safeinfer = $Typefrom($member.type).$eval($config.default_value);
              $else
                var val @safeinfer = ($Typefrom($member.type)) utils::@expand_val($config.default_value);
              $endif
              $if $defined(val!):
                if (catch val) {
                  val!;
                  return;
                }
              $endif
              cmd.$eval($member.name) = val;
            };

          $case !@is_maybe_type($member.type) &&& $member.type != bool &&& !$member.type.is_generic(List):
            var $name = @get_name($config);
            missing.push($name.len == 0 ??? @sprintf("<%s>", @str_upper($member.name)) : $name);
        $endswitch
      }
    $endif
  $endforeach

  if (missing.len() > 0) {
    io::eprintfn("Missing required option: %s", string::tjoin(missing.to_tarray(), ", "));
    return MISSING_REQUIRED_OPTION~;
  }
}

macro ArgConfig @setup_config($cmd_config, $arg) @const {
  ArgConfig $current_config = $arg.has_tag("seali:arg") ??? $arg.get_tag("seali:arg") : {};

  char $shortn = $current_config.shortn;
  String $longn = $current_config.longn;

  $if $current_config.autoshort:
    $shortn = $arg.name[0];
  $endif

  $if $current_config.autolong:
    $longn = @rename($cmd_config.rename_all, $arg.name);
  $endif

  $if $current_config.is_subcommand:
    $longn = $arg.name;
  $endif

  return {
    ...$current_config,
    .shortn = $shortn,
    .longn = $longn,
  };
}

macro String @rename(CaseConvention $convention, String $name) @local @const {
  $switch $convention:
    $case KEBAB_CASE:
      var $new_name = "";
      $foreach $v : $name:
        $if $v == '_':
          $new_name +++= "-";
        $else
          $new_name +++= $v;
        $endif
      $endforeach
      return $new_name;

    $case VERBATIM:
      return $name;

    $default:
      $error @sprintf("Not supported yet: %s", $convention);
  $endswitch
}

macro bool @arg_name_matches(ArgConfig $config, $member, value) {
  $if $config.is_subcommand:
    var $inner = @get_maybe_inner_type($member.type);
    $if !$inner.has_tag("seali:command"):
      $error "Subcommands must have the @Command attribute";
    $endif
    if (value == $inner.get_tag("seali:command").name) {
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

<*
  @returns "the number of consummed values"
*>
macro int? @arg_set_value(allocator, #cmd, $arg, $config, args, i) {
  var val = @arg_to_value(allocator, $arg.type, args, i, $config);
  $if $defined(val!):
    if (catch val) {
      val!;
      return 0;
    }
  $endif
  $if $arg.type.is_generic(List):
    if (!#cmd.$eval($arg.name).is_initialized()) #cmd.$eval($arg.name).init(allocator);
    #cmd.$eval($arg.name).push(val);
  $else
    #cmd.$eval($arg.name) = val;
  $endif
  return arg_type_size{$arg.type}(args.len);
}

fn int arg_type_size(int max) <Type> @local {
  $switch:
    $case Type::has_tag("seali:command"):
      return max;

    $case @is_maybe_type(Type):
      Type $t;
      return arg_type_size{$Typeof($t.value)}(max);

    $default:
      return 1;
  $endswitch
}

macro @arg_to_value(allocator, $Type, args, i, $config) @local {
  $if @is_maybe_type($Type):
    $Type $t;
    return maybe::value{$Typeof($t.value)}(@arg_to_value(allocator, $Typeof($t.value), args, i, $config));
  $endif


  $switch:
    $case $Type::is_generic(List):
      return @arg_to_value(allocator, $Type::generic_args[0], args, i, $config);

    $case $Type == bool:
      return true;

    $case $Type == int:
      String arg = args[i];
      return arg.to_int();

    $case $Type == char:
      String arg = args[i];
      return arg[0];

    $case $Type == uint:
      String arg = args[i];
      return arg.to_uint();

    $case $Type == String:
      return args[i];

    $case $Type::kind == ENUM:
      String arg = args[i];
      $switch $config.enum_as.type:
        $case DESCRIPTION:
          arg = arg.to_upper_tcopy();
          int found = -1;
          foreach(j, v : $Type::names) {
            if (v == arg) {
              found = (int) j;
              break;
            }
          }

          if (found == -1) {
            return INVALID_ENUM_VALUE~;
          }
          return $Type::values[found];

        $case ORDINAL:
          return $Type::from_ordinal(arg.to_int()!);

        $default:
          return $Type::lookup_field($eval($config.enum_as.field), arg);
      $endswitch

    $case $Type::has_tag("seali:command"):
      $Type sub;
      impl_parse{$Type}(allocator, &sub, args[i - 1..])!;
      return sub;

    // $default:
    //   $error "Unsupported type arg '" +++ $Type.nameof +++ "'";
  $endswitch
}

fn void? print_long_about() <Cmd> @private {
  $if !Cmd::has_tag("seali:command"):
    $error "Commands must be marked with the @Command tag";
  $endif

  var $name = Cmd::get_tag("seali:command").name;

  $switch: 
    $case Cmd::get_tag("seali:command").long_about.len != 0:
      io::printn(Cmd.get_tag("seali::command").long_about +++ "\n");

    $case Cmd::get_tag("seali:command").about.len != 0:
      io::printn(Cmd::get_tag("seali:command").about +++ "\n");

  $endswitch

  var $has_subcommands = false;
  $foreach $member : Cmd::members :
    $if $member.has_tag("seali:arg"):
      $if $member.get_tag("seali:arg").is_subcommand:
        $has_subcommands = true;
      $endif
    $endif
  $endforeach

  io::print(@sprintf("Usage %s", $name));
  $if @has_options_args(Cmd):
    io::print(" [OPTIONS]");
  $endif

  @print_required_args(Cmd);

  $if $has_subcommands:
    io::print(" <COMMANDS>");
    io::printn("\n");
    io::printn("Commands:");
    @print_subcommands(Cmd);
    io::printn();
  $else
    io::printn("\n");
  $endif
  $if @has_options_args(Cmd):
    io::printn("Options:");
    print_all_args{Cmd}();
    io::printn();
  $endif

  return HELP_PRINTED~;
}

fn void? print_short_about() <Cmd> @private {
  return print_long_about{Cmd}();
}

macro @print_subcommands($Cmd) @private {
  var $max_len = 0;
  $foreach $member : $Cmd::members :
    ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
    $if $config.is_subcommand:
      var $inner = @get_maybe_inner_type($member.type);
      $if !$inner.has_tag("seali:command"):
        $error "Subcommands must have the @Command attribute";
      $endif
      var $name = $inner.get_tag("seali:command").name;
      $if $name.len > $max_len:
        $max_len = $name.len;
      $endif
    $endif
  $endforeach

  $foreach $member : $Cmd::members :
    ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
    $if $config.is_subcommand:
      var $inner = @get_maybe_inner_type($member.type);
      $if !$inner.has_tag("seali:command"):
        $error "Subcommands must have the @Command attribute";
      $endif
      var $name = $inner.get_tag("seali:command").name;
      io::print(" " +++ $name);
      $for var $i = $name.len; $i < $max_len + 2; $i++:
        io::print(" ");
      $endfor
      $switch: 
        $case $inner.get_tag("seali:command").long_about.len != 0:
          io::printn($inner.get_tag("seali::command").long_about);

        $case $inner.get_tag("seali:command").about.len != 0:
          io::printn($inner.get_tag("seali:command").about);

      $endswitch
    $endif
  $endforeach
}

macro @has_options_args($Cmd) @private @const {
  var $has_required = false;
  $foreach $member : $Cmd::members :
    ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
    $if !$config.is_subcommand: // &&& ($config.default_value.len > 0 ||| @is_maybe_type($member.type)):
      return true;
    $endif
  $endforeach
  return false;
}

macro @print_required_args($Cmd) @private {
  $foreach $member : $Cmd::members :
    ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
    $if $config.default_value.len == 0 &&& !@is_maybe_type($member.type) &&& $member.type != bool:
      var $name = @get_name($config);
      $if $name.len > 0:
        io::print(" " +++ $name);
      $endif
      io::print(@sprintf(" <%s>", @str_upper($member.name)));
    $else
      $if $config.@is_unamed():
        io::print(@sprintf(" [<%s>]", @str_upper($member.name)));
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

macro int get_max_len() <Cmd> @local @const {
  var $max_len = 0;
  $foreach $member : Cmd::members :
    ArgConfig $config = @setup_config(Cmd::get_tag("seali:command"), $member);
    $if !$config.is_subcommand: // &&& ($config.default_value.len != 0 ||| @is_maybe_type($member.type)):
      var $all_names = @get_all_names($config);
      var $member_len = $all_names.len + @arg_value_to_string($member, $config).len + 2; // 2 spaces
      $if $member_len > $max_len:
        $max_len = $member_len;
      $endif
    $endif
  $endforeach

  return $max_len;
}

fn void print_all_args() <Cmd> @private {
  int $max_len = get_max_len{Cmd}();

  $foreach $member : Cmd::members :
    ArgConfig $config = @setup_config(Cmd::get_tag("seali:command"), $member);
    $if !$config.is_subcommand: //&&& ($config.default_value.len != 0 ||| @is_maybe_type($member.type)):
      var $all_names = @get_all_names($config);
      var $arg_value = @arg_value_to_string($member, $config);
      var $diff = $max_len + 1 - ($all_names.len + $arg_value.len + 2);

      String $spaces = { [0..$diff - 1] = ' ' };
      io::print(
        @sprintf(
          "%s%s %s%s", 
          $all_names.len == 0 ??? "" : " ", 
          $all_names, 
          $arg_value, 
          $all_names.len == 0 ??? " " : "",
        ) +++ $spaces
      );
      @print_arg_desc($member, $config);
      io::printn();
    $endif
  $endforeach
}

macro @arg_value_to_string($arg, $config) {
  $switch:
    $case $arg.type == bool:
      return "";

    $default:
      return @sprintf("<%s>", @str_upper($arg.name));
  $endswitch
}

macro @print_arg_desc($arg, ArgConfig $config) {
  $if $config.help.len > 0:
    io::printf(@sprintf(" %s", $config.help));
  $endif

  $if $arg.type.kind == ENUM:
    String $s = "";
    $switch $config.enum_as.type:
      $case DESCRIPTION:
        $foreach $i, $name : $arg.type.names:
          $if $i != 0:
            $s +++= " | ";
          $endif
          $s +++= @str_lower($name);
        $endforeach

      $case ORDINAL:
        $s = @sprintf("0..%s", $arg.type.values.len - 1);

      $default:
        $foreach $i, $value : $arg.type.values:
          $if $i != 0:
            $s +++= " | ";
          $endif
          $s +++= @str_lower($value.$eval($config.enum_as.field));
        $endforeach
    $endswitch
    io::printf(@sprintf(" {values: %s}", $s));
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
          ($defined($value.get()!) ||| $defined($value == maybe::value{$Typeof($value.value)}($value.value))));
}

macro @is_maybe_type($Type) {
  $Type $value;
  return ($defined($value.get) &&& $defined($value.get()) &&& 
          ($defined($value.get()!) ||| $defined($value == maybe::value{$Typeof($value.value)}($value.value))));
}

macro @get_maybe_inner_type($Type) {
  $if @is_maybe_type($Type):
    $Type $t;
    return @get_maybe_inner_type($Typeof($t.value));
  $endif
  return $Type;
}

// macro parse($Cmd, String[] _args) {
//   var args = _args[1..];
//
//   if (args.len == 0 && $Cmd::get_tag("seali:command").help_on_empty) {
//     print_long_about($Cmd);
//   }
//
//   List{String} args_with_values;
//   args_with_values.init(mem);
//   defer args_with_values.free();
//
//   $Cmd cmd;
//
//   // set the default value of all the field that have one
//   $foreach $member : $Cmd::members :
//     ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
//     $if !$config.skip:
//       $if $config.default_value.len > 0:
//         args_with_values.push($member.name);
//         do {
//           $if $member.type.kind == ENUM:
//             $if $config.default_value[0] == '"' ||| !$defined($Typefrom($member.type).$eval($config.default_value)):
//               $error @sprintf("The default value of an enum member must be the member's description without the type (found %s).", $config.default_value);
//             $endif
//             var val = $Typefrom($member.type).$eval($config.default_value);
//           $else
//             var val = ($Typefrom($member.type)) utils::@expand_val($config.default_value);
//           $endif
//           $if $defined(val!):
//             if (catch val) {
//               val!;
//               return cmd;
//             }
//           $endif
//           cmd.$eval($member.name) = val;
//         };
//       $endif
//       $if @is_maybe_type($member.type):
//         args_with_values.push($member.name);
//       $endif
//     $endif
//   $endforeach
//
//   List{String} got_value;
//   got_value.init(mem);
//   defer got_value.free();
//
//   int i = 0;
//   while (i < args.len) {
//     String name;
//     if (try eq_idx = args[i].index_of("=")) {
//       name = args[i][..eq_idx - 1];
//       args[i] = args[i][eq_idx + 1..args[i].len-1];
//     }
//     $foreach $member : $Cmd::members:
//       ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
//       $if !$config.skip:
//         if (args[i] == "--help") print_long_about($Cmd);
//         if (args[i] == "-h") print_short_about($Cmd);
//
//         if (name.len > 0) {
//           if (@arg_name_matches($config, $member, name) && !got_value.contains($member.name)) {
//             args_with_values.push($member.name);
//             got_value.push($member.name);
//             i += @arg_set_value(cmd, $member, $config, args, i)!;
//             continue;
//           }
//         } else if (@arg_name_matches($config, $member, args[i]) && !got_value.contains($member.name)) {
//           args_with_values.push($member.name);
//           got_value.push($member.name);
//           $if !($config.@is_unamed() ||| $member.type == bool):
//             i++;
//           $endif
//           i += @arg_set_value(cmd, $member, $config, args, i)!;
//           continue;
//         }
//       $endif
//     $endforeach
//
//     io::eprintfn("Unknown option '%s'\n", args[i]);
//     libc::exit(-1);
//   }
//
//   var has_missing = false;
//   // check that each field has been initialized
//   $foreach $member : $Cmd::members:
//     ArgConfig $config = @setup_config($Cmd::get_tag("seali:command"), $member);
//     $if !$config.skip:
//       if (!args_with_values.contains($member.name)) {
//         if (!has_missing) {
//           io::eprint("Missing required option ");
//         } else {
//           io::eprint(", ");
//         }
//         var $name = @get_name($config);
//         $if $name.len == 0:
//           io::eprint(@sprintf("<%s>", @str_upper($member.name)));
//         $else
//           io::eprint($name);
//         $endif
//         has_missing = true;
//       }
//     $endif
//   $endforeach
//
//   if (has_missing) {
//     io::eprintn();
//     libc::exit(-1);
//   }
//
//   return cmd;
// }

// macro print_long_about($Cmd) @private {
//   $if !$Cmd::has_tag("seali:command"):
//     $error "Commands must be marked with the @Command tag";
//   $endif
//
//   var $name = $Cmd::get_tag("seali:command").name;
//
//   $switch: 
//     $case $Cmd::get_tag("seali:command").long_about.len != 0:
//       io::printn($Cmd.get_tag("seali::command").long_about +++ "\n");
//
//     $case $Cmd::get_tag("seali:command").about.len != 0:
//       io::printn($Cmd::get_tag("seali:command").about +++ "\n");
//
//   $endswitch
//
//   var $has_subcommands = false;
//   $foreach $member : $Cmd::members :
//     $if $member.has_tag("seali:arg"):
//       $if $member.get_tag("seali:arg").is_subcommand:
//         $has_subcommands = true;
//       $endif
//     $endif
//   $endforeach
//
//   io::print(@sprintf("Usage %s", $name));
//   $if @has_options_args($Cmd):
//     io::print(" [OPTIONS]");
//   $endif
//
//   @print_required_args($Cmd);
//
//   $if $has_subcommands:
//     io::print(" <COMMANDS>");
//     io::printn("\n");
//     io::printn("Commands:");
//     @print_subcommands($Cmd);
//     io::printn();
//   $else
//     io::printn("\n");
//   $endif
//   $if @has_options_args($Cmd):
//     io::printn("Options:");
//     @print_all_args($Cmd);
//     io::printn();
//   $endif
//   libc::exit(0);
// }
