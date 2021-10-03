import js.html.TextAreaElement;
import js.html.Event;
import js.html.InputElement;
import js.Browser;

import base.Preprocessor;
import base.Tokenizer;
import base.Parser;

function main() {
	final Preprocessor = new Preprocessor();
	final Tokenizer = new Tokenizer();
	final Parser = new Parser();

	final input_textarea: TextAreaElement = cast Browser.document.getElementById("input");
	final output_textarea: TextAreaElement = cast Browser.document.getElementById("output");

	input_textarea.onkeypress = function(e:Event) {
		try {
			final processed = Preprocessor.process(input_textarea.value);
			final tokens = Tokenizer.process(processed);
			final ast = Parser.process(tokens);

			final out_code = base.transpiler.Lua.process(ast);

			output_textarea.value = out_code;
		} catch(exception) {
			output_textarea.value = exception.toString();
		}
	};
}