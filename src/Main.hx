import base.Preprocessor;

#if sys

final CODE: String = CompileTime.readFile("script.e2");

final PREPROCESSOR = new base.Preprocessor();
final TOKENIZER = new base.Tokenizer();
final PARSER = new base.Parser();

function main() {
	final code = PREPROCESSOR.process(CODE);
	final tokens = TOKENIZER.process(code);
	final ast = PARSER.process(tokens);
	final lua_code = base.transpiler.Lua.process(ast);

	if (!sys.FileSystem.exists("out"))
	sys.FileSystem.createDirectory("out");

	final handle = sys.io.File.write('out/script.lua');
		handle.writeString(lua_code);
	handle.close();

	trace("Finished transpiling!");
}

#end