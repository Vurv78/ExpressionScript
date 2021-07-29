package tests.utest;

import utest.Assert;
import utest.Test;

import lib.Type.E2Type;

class Tokenizer extends Test {
	/**
	 * Make sure we properly get the literal number value out of a basic operation.
	 */
	public function testLiteralNumber() {
		final tokens = base.Tokenizer.process("Var = 212");
		Assert.equals( E2Type.Number(212), tokens[2].literal );
	}
}