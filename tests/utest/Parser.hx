package tests.utest;
import sys.FileSystem;
import base.Tokenizer.Token;

// TODO: Fix this entire test

import utest.Assert;
import utest.Test;

class Parser extends Test {
	//var tokens: Array<Token>;
	var parser: base.Parser;
	var script: String;

	/*
		Haxe/utest is fucking stupid 👍
	public function setup() {
		this.script = sys.io.File.getContent("tests/data/test_script.e2");

		this.parser = new base.Parser();

		final tokenizer = new base.Tokenizer();
		var a = tokenizer.process(this.script);
	}
	*/

	public function testInstruction() {
		//final instr = this.parser.process(this.tokens);

		//Assert.equals(instr.name, "seq");
		//Assert.same({char: 0, line: 1}, instr.trace);
	}
}