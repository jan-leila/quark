const moo = require('moo')
 
let lexer = moo.states({
	main: {
		whitespace: [{ match: /[ \n\t]+/, lineBreaks: true }, /[ \t]+/s],
		comment: [
			{ match: /\/\/.*?(?:\n|$)/, lineBreaks: true },
			{ match: /\/\*[^]*?\*\//, lineBreaks: true },
		],

		hex: /0x[0-9a-fA-F]+/,
		int: /[0-9]+(?![0-9]*\.)/,
		float: /(?:0|[1-9][0-9]*)(?:\.[0-9])?[0-9]*/,

		string: [
			{ match: /".*?(?<!\\)(?:\\\\)*"/s, lineBreaks: true },
			{ match: /'.*?(?<!\\)(?:\\\\)*'/s, lineBreaks: true }
		],
		lit_str_start: { match: '`', push: 'str_lit' },

		lparen: '(',
		rparen: ')',
		lcbracket: { match: '{', push: 'main' },
		rcbracket: { match: '}', pop: true },
		lbracket: '[',
		rbracket: ']',

		colon: ':',
		spread: '...',
		question: '?',
		dot: '.',
		comma: ',',

		arrow: "=>",

		impl_tag_close: "/>",
		tag_close: "</>",

		condition: {
			match: [
				'!=', '>=', '<=', '==',
			],
			type: moo.keywords({
				assignment: '=',
			}),
		},
		assignment: {
			match: [
				'=', '+=', '-=', '*=', '/=', '%=', '**=', '&=', '|=', '~=', '^=', '<<<=', '>>>=', '<<=', '>>=', '&&=', '||=', '<<=', '>>=', '++', '--',
			],
			type: moo.keywords({
				operator: [
					'+', '-', '*', '/', '%', '**', '&', '|', '~', '^', '<<<', '>>>', '<<', '>>', '&&', '||', '<<', '>>', '!',
				],
			}),
		},
		operator: [
			'+', '-', '*', '/', '%', '**', '&', '|', '~', '^', '<<<', '>>>', '<<', '>>', '&&', '||', '<<', '>>', '!',
		],

		lbrace: '<',
		rbrace: '>',

		identifier: {
			match: /\w+/, type: moo.keywords({
				control: [
					// control structures
					'if', 'else', 'do', 'switch', 'case', 'while', 'for', 'break', 'continue', 'return',
				],
				object: [
					'enum', 'struct', 'function', 'component',
				],
				extentions: [
					// extention
					'extends',
				],
				type: [
					// data types
					'let', 'boolean', 'int', 'float', 'symbol', 'null', 'object', 'function', 'char', 'component',
				],
				access: [
					// access modifiers
					'public', 'private', 'protected', 'package',
				],
				modifier: [
					// value modifiers
					'static', 'final', 'strict',
				],
				import: [
					// importing
					'import', 'from', 'as',
				],
				export: [
					'export', 'default',
				],
				null: [
					'null', 'undefined',
				],
			})
		},
		control: [
			// control structures
			'if', 'else', 'do', 'switch', 'case', 'while', 'for', 'break', 'continue', 'return',
		],
		object: [
			'enum', 'struct', 'function', 'component',
		],
		extentions: [
			// extention
			'extends',
		],
		type: [
			// data types
			'let', 'boolean', 'int', 'float', 'symbol', 'object', 'function', 'char', 'component',
		],
		access: [
			// access modifiers
			'public', 'private', 'protected', 'package',
		],
		modifier: [
			// value modifiers
			'static', 'final',
		],
		import: [
			// importing
			'import', 'from', 'as',
		],
		export: [
			'export', 'default',
		],
		null: [
			'null', 'undefined',
		],
		break: ';',
	},
	str_lit: {
		interp: { match: '${', push: 'main' },
		escape: /\\./,
		lit_str_end: { match: '`', pop: true },
		str_content: { match: /(?:[^$`]|\$(?!\{))+/, lineBreaks: true },
	},
});

module.exports = {
	next: () => {
		let next;
		do {
			next = lexer.next();
			if(next == undefined){
				return;
			}
		} while(next.type === 'comment');
		// console.log(next);
		return next;
	},
	save: () => {
		return lexer.save();
	},
	reset: (chunk, info) => {
		return lexer.reset(chunk, info);
	},
	formatError: (token) => {
		return lexer.formatError(token);
	},
	has: (name) => {
		return lexer.has(name);
	},
};