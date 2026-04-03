module seali;

import std::io;

struct Cli @Command("myapp") 
  @About("My awesome CLI application")
{
  String input_file @Short @Long @Help("Input file path");
  bool verbose @ShortName('V') @Long @Default(false) @Help("Enable verbose output");
  String output @Short @LongName("output") @Help("Output file");
  uint threads @Short @Default(4) @Help("Number of threads");
}


fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args)!!;

  io::printfn("%s\n", string::from_struct(mem, cli));

	return 0;
}
