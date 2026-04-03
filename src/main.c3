module seali;

import std::io;

struct Cli @Command("demo") 
  @About("Simple program to greet a person")
  @RenameAll(PASCAL_CASE)
{
  String name @Short @Long @Help("Your name");
  uint count @Short @Long @Default(1) @Help("The number of times to greet");
}


fn int main(String[] args) {
  Cli cli = seali::parse(Cli, args);

	return 0;
}
