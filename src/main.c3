module seali;

import std::io;

struct Cli @Command("myapp") 
  @About("My awesome CLI application")
{
  String input_file @Seali(@arg(short, long, help = "Input file path"));
  bool verbose @Seali(@arg(short = 'V', long, default_value = false, help = "Enable verbose output"));
  String output @Seali(@arg(short, long = "out", help = "Output file"));
  uint threads @Seali(@arg(short, default_value = 4, help = "Number of threads"));
}


fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args)!!;

  io::printfn("%s\n", string::from_struct(mem, cli));

	return 0;
}
