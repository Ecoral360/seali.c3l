module main @feat(SEALI_DEV);
import seali;
import derive;
import std::io;
import std::collections::maybe;

enum LogLevel : (String name) {
  VERBOSE { "verbose" },
  DEBUG { "debug" },
  INFO { "information" },
  WARN { "warn" },
  ERROR { "error" },
}

// $expand(derive(EnumDesCli::name, seali));
// struct EnumDesCli @Command({.name = "t"}) {
//   LogLevel log_level_description @Seali(arg(long, help = "Log level", default_value = VERBOSE));
//   LogLevel log_level_ordinal @Seali(arg(long, help = "Log level", enum_as = ORDINAL));
//   LogLevel log_level_field @Seali(arg(long, help = "Log level", enum_as = name, default_value = WARN));
//   String file_path @Seali(arg(long, help = "The file path"));
// }

$expand(seali::@derive(CliArgs));
struct CliArgs @Command({ .name = "c3_ls" })
{
	Maybe{String} stdlib_path   @Seali(arg(long, help = "The std path"));
	Maybe{String} compiler_path @Seali(arg(long, help = "Path to C3 compiler binary"));
	Maybe{String} log_path      @Seali(arg(long, help = "Path to log file"));
	Maybe{String} cache_path    @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path2   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path3   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path4   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path5   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path6   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path7   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path8   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path9   @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path10  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path11  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path12  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path13  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path14  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path15  @Seali(arg(long, help = "Override where the cache files are stored"));
	Maybe{String} cache_path16  @Seali(arg(long, help = "Override where the cache files are stored"));
	LogLevel log_level          @Seali(arg(long, help = "log level", default_value = ERROR));
	uint diagnostics_delay      @Seali(arg(short, long, help = "delay"));
	bool send_crash_reports     @Seali(arg(long, help = "send crash reports", default_value = false));
  String hello                @Seali(arg(skip));
}



fn void main(String[] args) {
  CliArgs cli;
  cli.tparse(args)!!;

  io::printn(cli);
}
