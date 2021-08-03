package base;

import haxe.exceptions.NotImplementedException;
import haxe.ValueException;
import lib.Type.E2Type;
import haxe.ds.Option;
using hx.strings.Strings;
using Safety;

enum TokenType {
	Literal;
	Identifier;
	Type;
	Constant;
	Operator;
	Grammar;
	Whitespace;
	Keyword;

	Invalid;
}

@:enum abstract TokenFlag(Int) {
	var None = 0;
	var NoCatch = 1;

	@:op(a|b) static function or(a:TokenFlag,b:TokenFlag) : TokenFlag;
	@:op(a&b) static function and(a:TokenFlag,b:TokenFlag) : TokenFlag;

	public inline function new(i = 0) this = i;

	public inline function has( v : TokenFlag ) : Bool
		return (this & v.toInt()) == v.toInt();

	public inline function set( v : TokenFlag ) : Void
		this |= v.toInt();

	public inline function unset( v : TokenFlag ) : Void
		this &= 0xFFFFFFFF - v.toInt();

	public inline function toInt()
		return this;

	public inline static function ofInt( i : Int ) : TokenFlag
		return new TokenFlag(i);
}

class TokenMatch {
	final pattern: EReg;

	public final id: String;
	public final flag: TokenFlag;
	public final tt: TokenType;
	final processor: Null<(token: Token, pattern: EReg)->Void>;

	public function new(identifier: String, pattern: EReg, tt: TokenType, ?flag: TokenFlag, ?processor: (token: Token, pattern: EReg)->Void ) {
		this.id = identifier;
		this.tt = tt;
		this.flag = flag;
		this.pattern = pattern;
		this.processor = processor;
	}

	public function match(haystack: String, pos: Int = 0): Null<Token> {
		if ( this.pattern.matchSub(haystack, pos) ) {
			final matchedpos = this.pattern.matchedPos();
			if (matchedpos.pos == pos) {
				var tok = Token.from( matchedpos, this.pattern.matched(0), this );
				if (this.processor != null)
					this.processor(tok, this.pattern);

				return tok;
			}
		}
		return null;
	}
}

class Token {
	public final start: Int;
	public final len: Int;
	public final end: Int;
	public var raw: String;

	public var id: String;
	public final flag: TokenFlag;
	public var tt: TokenType;

	public var literal: E2Type; // Inferred value or the string that is more specifically the value.

	// Debug / Stack
	public var line: Int;
	public var char: Int;
	public var whitespaced: Bool; // Whether the token was preceeded by whitespace.

	public function new( pos: Int, len: Int, raw: String, id: String, flag: TokenFlag, tt: TokenType ) {
		this.start = pos;
		this.end = pos + len;
		this.len = len;
		this.raw = raw;

		this.id = id;
		this.flag = flag;
		this.tt = tt;

		// Stack / Debug
		this.char = pos;
		this.line = 1; // Will be assigned after

		this.literal = E2Type.Void;
	}

	public static function from( result: {pos: Int, len: Int}, raw: String, matcher: TokenMatch ): Token {
		return new Token(
			result.pos,
			result.len,
			raw,
			matcher.id,
			matcher.flag,
			matcher.tt
		);
	}

	// Debugging
	function toString() {
		return 'Token [pos: {${this.start}, ${this.end}}, tt: ${this.tt}, raw: "${this.raw}", id: ${this.id}, line: ${this.line}, %s: ${this.whitespaced}, literal: ${this.literal}]';
	}
}

class Tokenizer {
	var token_matchers: Array<TokenMatch>;
	public function new() {
		this.token_matchers = [
			new TokenMatch( "whitespace", ~/\s+/, TokenType.Whitespace, TokenFlag.NoCatch ),

			new TokenMatch( "grammar", ~/{|}|,|;|:|\(|\)|\[|\]/, TokenType.Grammar),

			new TokenMatch( "keyword", ~/elseif|if|else|break|continue|local|while|switch|case|default|try|catch|foreach|for|function|return|do/, TokenType.Keyword ),

			new TokenMatch( "string", ~/("[^"\\]*(?:\\.[^"\\]*)*")/, TokenType.Literal, TokenFlag.None, function(token, pattern) {
				return E2Type.String( pattern.matched(0) );
			}),

			new TokenMatch( "number", ~/-?(\d*\.)?\d+/, TokenType.Literal, TokenFlag.None, function(token, pattern) {
				// In the future make this allow for rust strings etc
				var value = Std.parseFloat( pattern.matched(0) );
				if (Math.isNaN(value))
					throw "Invalid number matched! Wtf????"; // Shouldn't happen as long as our regex is good.
				token.literal = E2Type.Number(value);
			}),

			new TokenMatch( "constant", ~/_\w[_\w]*/, TokenType.Constant, TokenFlag.None, function(token, pattern) {
				var name = pattern.matched(0);

				// Turn the constant token into a literal token
				// This is a really weird system and exactly how E2 does it. I might move this logic to the preprocessor at some point
				// (When I make it not fuck up traces)
				token.id = "number";
				token.literal = E2Type.Number(1000);
				token.tt = TokenType.Literal;
				token.raw = "1000";
			}),
			new TokenMatch( "identifier", ~/[A-Z]\w*/, TokenType.Identifier ), // Variable name.
			new TokenMatch( "func_name", ~/[a-z]\w*/, TokenType.Identifier ),
			new TokenMatch( "type", ~/[a-z]+/, TokenType.Type ),
			new TokenMatch( "operator", ~/==|!=|\*=|\+=|-=|\/=|%=|<<|>>|&&|\|{2}|\+{2}|->|>=|<=|\^{2}|\?:|<|>|\+|-|\*|\/|=|!|~|\$|~|\?|%|\||\^|&|:/, TokenType.Operator )
		];
	}

	public function process(script: String): Array<Token> {
		var out = [];
		var pointer = 0; // Current position
		var cur_line = 1;
		var whitespaced = false; // Whether the token was preceeded by whitespace.

		var did_match;
		do {
			did_match = false;
			for (tokenizer in this.token_matchers) {
				final name = tokenizer.id;
				final token = tokenizer.match(script, pointer);
				if ( token != null ) {
					pointer = token.end;
					if ( !tokenizer.flag.has(TokenFlag.NoCatch) ) {
						token.line = cur_line;
						token.whitespaced = whitespaced;
						out.push(token);
					} else if (token.tt == TokenType.Whitespace) {
						cur_line += token.raw.countMatches("\n");
					}
					whitespaced = ( token.tt == TokenType.Whitespace );
					did_match = true;
					break;
				}
			}
			if (!did_match)
				throw new haxe.Exception('Unknown character ["${ script.charAt(pointer) }"] at line $cur_line, char $pointer in script.');
		} while( pointer < script.length );

		return out;
	}
}