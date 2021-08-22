package base;
using hx.strings.Strings;

private function FILL_WHITESPACE(x: EReg) {
	return ' '.repeat(x.matched(0).length);
}

/**
 * Preprocessor class
 * Has a basic regex Map (repl) that can be used to preprocess code before running.
 * You can modify the regexes to your needs but by default will remove comments & directives.
 */
class Preprocessor {
	var repl: Map<EReg, (EReg)->String>;

	public function process(script: String) {
		var processed = script;

		for (regex => with in repl)
			processed = regex.map( processed, with );

		return processed;
	}

	public function new() {
		final repl = [
			~/#\[[\s\S]*\]#/g => FILL_WHITESPACE, // Single-line comment
			~/#[^\n]*/g => FILL_WHITESPACE, // Multiline
			~/@[^\n]*/g => FILL_WHITESPACE // Directive
		];
		this.repl = repl;
	}
}