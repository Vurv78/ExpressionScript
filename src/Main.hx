using Iterators;

final CODE: String = CompileTime.readFile("script.e2");

function main() {
	final preprocessor = new base.Preprocessor();
	final code = preprocessor.process(CODE);

	final tokenizer = new base.Tokenizer();
	final tokens = tokenizer.process(code);

	final parser = new base.Parser();
	final ast = parser.process(tokens);

	final lua_code = base.transpiler.Lua.process(ast);

	#if sys
		if (!sys.FileSystem.exists("out"))
		sys.FileSystem.createDirectory("out");

		final handle = sys.io.File.write('out/script.lua');
			handle.writeString(lua_code);
		handle.close();
	#end

	trace("Finished transpiling!");
}