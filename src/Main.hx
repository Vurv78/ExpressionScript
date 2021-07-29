import sys.FileSystem;
import sys.io.File;
using Iterators;
final CODE = sys.io.File.getContent("script.e2");

function main() {
	final tokens = base.Tokenizer.process(CODE);

	final parser = new base.Parser();
	var stuff = parser.process(tokens);

	var code = base.transpiler.Lua.process(stuff);

	if (!FileSystem.exists("out"))
		FileSystem.createDirectory("out");

	final handle = sys.io.File.write('out/script.lua');
		handle.writeString(code);
	handle.close();

	Sys.println("Done!");
}