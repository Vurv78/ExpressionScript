package tests.utest;

import utest.Assert;
import utest.Test;

import lib.Type.E2Type;

class Preprocessor extends Test {
	var processor: base.Preprocessor;
	var script: String;

	public function setup() {
		this.script = sys.io.File.getContent("tests/data/pp.e2");
		this.processor = new base.Preprocessor();
	}

	/**
	 * Make sure the preprocessor properly strips out directives and comments
	 */
	public function testPreprocess() {
		var result = this.processor.process(this.script);
		Assert.equals(result, '\n\nprint("Hello world")');
	}
}