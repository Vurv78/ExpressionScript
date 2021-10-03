package utests;
import lib.Instructions.Instr;
import base.Tokenizer.Token;

import utest.Assert;
import utest.Test;

@:keep
class LuaTranspile extends Test {
	public function testReflect() {
		for (instr_id in Type.getEnumConstructs(Instr) ) {
			instr_id = instr_id.toLowerCase();
			if ( !Reflect.hasField( base.transpiler.Lua.Instructions, 'instr_$instr_id' ) )
				Assert.warn('Missing field [instr_$instr_id] for Lua transpiler.');
		}
		Assert.pass();
	}
}