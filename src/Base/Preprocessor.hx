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
	var repl: Map<EReg, (EReg)->String> = [];
	var repl_order: Array<EReg> = [];
	var repl_order_index: UInt = 0;

	public function process(script: String) {
		var processed = script;

		for (regex in repl_order) {
			var replacement = this.repl[regex];
			if (replacement != null)
				processed = regex.map( processed, replacement );
		}

		return processed;
	}

	public function add_replacement(regex: EReg, with: (EReg)->String) {
		// Haxe is dying with optionals for me so I can't have an override for repl_order_index. :/
		this.repl_order[repl_order_index] = regex;
		this.repl_order_index++;
		this.repl[regex] = with;
	}

	public function new() {
		this.add_replacement( ~/#\[[\s\S]*\]#/g, FILL_WHITESPACE ); // Multiline comment
		this.add_replacement( ~/#[^\n]*/g, FILL_WHITESPACE ); // Single line comment
		this.add_replacement( ~/@[^\n]*/g, FILL_WHITESPACE ); // Directive
	}
}