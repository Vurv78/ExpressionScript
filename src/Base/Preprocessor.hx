package base;


/**
 * Preprocessor class
 * Has a basic regex Map (repl) that can be used to preprocess code before running.
 * You can modify the regexes to your needs but by default will remove comments & directives.
 */
class Preprocessor {
	var repl: Map<EReg, String>;
	public function process(script: String) {
		var processed = script;
		for (regex => with in repl)
			processed = regex.replace(processed, "");

		return processed;
	}

	public function new() {
		final repl = [
			~/#[^\n]*/g => "", // Single-line comment
			~/#\[[\s\S]*\]#/g => "", // Multiline
			~/@[^\n]*/g => "" // Directive
		];
		this.repl = repl;
	}
}