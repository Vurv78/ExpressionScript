import base.Preprocessor;

#if sys

final CODE: String = CompileTime.readFile("script.e2");

final PREPROCESSOR = new base.Preprocessor();
final TOKENIZER = new base.Tokenizer();
final PARSER = new base.Parser();
final COMPILER = new base.Compiler();

function main() {
	final code = PREPROCESSOR.process(CODE);
	final tokens = TOKENIZER.process(code);
	final ast = PARSER.process(tokens);
	final runtime = COMPILER.process(ast);
	//final lua_code = base.transpiler.Lua.process(ast);

	trace("Finished compile, running!");

	runtime();
}

#end