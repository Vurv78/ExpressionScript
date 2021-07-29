# ExpressionScript
A language heavily derived from Expression2.  
This was originally created to be a template to rewrite E2 for S&box, however at this point I don't really care about S&box nor am I interested in C#.  

## Compiler
The compiler currently hasn't been finished. Most of the work has been done on the *Transpiler* for now.

## Transpiler
This project allows you to convert ExpressionScript code to any language, as long as a transpiler is provided.  
By default a Lua transpiler is provided and more may come.  

## Differences

### No ``normal``
Normal is a type that came before ``number``, however nobody uses it and it just complicates things.

### No inputs
For obvious reasons, there's no io or entities in this as this is meant to be run in the browser, or simply on your pc.

### Fixed bitwise operators
E2 randomly swapped || and | / & and &&. && was made into bitwise and rather than logical and.  
*It has been switched to match typical language spec.  *

### Optimized
The language is optimized for speed. E2 was known to be very slow, and this is no longer the case through typing and other optimizations.  
*Although, admittedly Haxe is nowhere near the best language for trying to get something to be fast.

General State:
| Name | Status | Desc |
| ---  | ---    |  ---  |
| Preprocessor | 🚧 | Unfinished |
| Tokenizer | ✔️| Tokenizer should be completely finished. Some operators and grammar might be missing that I'm unaware of. |
| Parser | 🚧🏗️ | It is nearly done, however some things like #include are missing, and some statements/expressions might be buggy. |
| Optimizer | ❌ | Hasn't been started and there are no plans for this yet. |
| Compiler| 🚧 | Unfinished. |
| Transpiler| 🚧🏗️ | Unfinished. |
| Tests| 🚧 | Unfinished. |