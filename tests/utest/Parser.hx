package tests.utest;
import base.Tokenizer.Token;

// TODO: Fix this entire test

import utest.Assert;
import utest.Test;

// Get script at compile time
macro function getScript() {
	return macro $v{sys.io.File.getContent("tests/data/test_script.e2")};
}

class Parser extends Test {
	var tokens: Array<Token>;
	var parser: base.Parser;

	public function setup() {
		this.parser = new base.Parser();
		this.tokens = base.Tokenizer.process( getScript() );
	}

	public function testInstruction() {
		final instr = this.parser.process(this.tokens);

		Assert.equals(instr.name, "seq");
		Assert.same(instr.trace, {char: 0, line: 1});
	}
}