import sys.FileSystem;
import sys.io.File;
using Iterators;
final CODE = sys.io.File.getContent("script.e2");

function main() {
	final preprocessor = new base.Preprocessor();
	final code = preprocessor.process(CODE);

	final tokenizer = new base.Tokenizer();
	final tokens = tokenizer.process(code);

	final parser = new base.Parser();
	final ast = parser.process(tokens);

	final lua_code = base.transpiler.Lua.process(ast);

	if (!FileSystem.exists("out"))
		FileSystem.createDirectory("out");

	final handle = sys.io.File.write('out/script.lua');
		handle.writeString(lua_code);
	handle.close();

	Sys.println("Done!");
}