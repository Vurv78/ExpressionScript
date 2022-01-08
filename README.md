# ExpressionScript [![Release Shield](https://img.shields.io/github/v/release/Vurv78/ExpressionScript?include_prereleases)](https://github.com/Vurv78/ExpressionScript/releases/latest) [![License](https://img.shields.io/github/license/Vurv78/ExpressionScript?color=red&include_prereleases)](https://github.com/Vurv78/ExpressionScript/blob/master/LICENSE.md) [![Linter Badge](https://github.com/Vurv78/ExpressionScript/workflows/tests/badge.svg)](https://github.com/Vurv78/ExpressionScript/actions) [![github/Vurv78](https://img.shields.io/discord/824727565948157963?label=Discord&logo=discord&logoColor=ffffff&labelColor=7289DA&color=2c2f33)](https://discord.gg/yXKMt2XUXm)
> Expression2 rewritten in Haxe.  

# ⚠️ Notice ⚠️
This was a cool project, but I might've put too much of an emphasis on backwards compatibility, the one thing holding me back on E2 in the first place. Since I'm not making progress on this nor E2, you might want to see https://github.com/Vurv78/Expression4 while this is on hold. It doesn't help that I've kind of fallen out of heart for Haxe. If this does come back, it may be in Rust ⚙️.

##  Readme
This was originally created to be a template to rewrite E2 for S&box, however at this point S&Box looks awful and I'm not interested in C#.  
All credit and ownership of Expression2 goes to the [wireteam](https://github.com/wiremod) & [wiremod](https://github.com/wiremod/wire).  

## Transpiler
This project allows you to convert ExpressionScript code to any language, as long as a transpiler is provided.  
By default a Lua transpiler is provided and more may come.  

## Differences

### No ``normal``
Normal is a type that came before ``number``, however nobody uses it and it just complicates things.

### No inputs
For obvious reasons, there's no io or entities in this as this is meant to be run in the browser, or simply on your pc.
### Optimized
The language is optimized for speed. E2 was known to be very slow, and this is no longer the case through typing and other optimizations.  
*Although, admittedly Haxe is nowhere near the best language for trying to get something to be fast.

## General State
Here's a general status of each part of the language.
| Name | Status |              Desc |
| ---  | ---    |              ---  |
| Preprocessor       | 🚧    | No support for directives (I mean what would they do?). Of course they alongside comments are stripped out of code. Missing #ifdef, etc. |
| Tokenizer          | ✔️    | Tokenizer should be completely finished. Some operators and grammar might be missing that I'm unaware of. |
| Parser             | 🚧🏗️ | It is nearly done, however some things like #include are missing, and some statements/expressions might be buggy. |
| Optimizer          | ❌    | Hasn't been started and there are no plans for this yet. |
| Compiler           | 🚧    | I have not started work on this yet. |
| (Lua) Transpiler   | ✔️🏗️ | Mostly done. |
| Tests              | ✔️    | Unit tests are used to verify integrity of the language. |

## Running Tests
Tests are using the [utest](https://github.com/haxe-utest/utest) library.  
Use ``haxe test.hxml`` to run them.
