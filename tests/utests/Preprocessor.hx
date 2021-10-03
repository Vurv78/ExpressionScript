package utests;

import utest.Assert;
import utest.Test;

import lib.Type.E2Value;

using hx.strings.Strings;

class Preprocessor extends Test {
	var processor: base.Preprocessor;
	var script: String;

	public function setup() {
		this.script = CompileTime.readFile("tests/data/pp.e2");
		this.processor = new base.Preprocessor();
	}

	/**
	 * Make sure the preprocessor properly strips out directives and comments
	 */
	public function testPreprocess() {
		var result = this.processor.process(this.script);

		// It should replace the directive with 8 spaces.
		Assert.equals('         \nprint("Hello world")', result );
	}
}