package tests.utest;

import utest.Assert;
import utest.Test;

import lib.Type.E2Type;

class Tokenizer extends Test {
	var script: String;
	var tokenizer: base.Tokenizer;

	/**
	 * Setup our Tokenizer struct
	 */
	public function setup() {
		this.script = "Var = 212";
		this.tokenizer = new base.Tokenizer();
	}

	/**
	 * Make sure we properly get the literal number value out of a basic operation.
	 */
	public function testLiteralNumber() {
		final tokens = this.tokenizer.process(this.script);
		Assert.equals( E2Type.Number(212), tokens[2].literal );
	}
}