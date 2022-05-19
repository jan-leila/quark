const moo = require('moo')

const conditionals = [
	'?.', '?[', '?(', "?=", '??', '?>',
];
const operators = [
	'+', '-', '*', '/', '%', '**', '&', '|', '~', '^', '<<<', '>>>', '<<', '>>', '&&', '||', '<<', '>>', '!',
];

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
		dot: '.',
		comma: ',',

		arrow: "=>",

		impl_tag_close: "/>",
		tag_close: "</",

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
				operator: operators,
			}),
		},

		question: {
			match: [ '?' ],
			type: moo.keywords({
				operator: conditionals,
			}),
		},
		larrow: '<',
		rarrow: '>',

		operator: [ ...operators, ...conditionals ],

		identifier: {
			match: /\w+/, type: moo.keywords({
				control: [
					'if', 'else', 'do', 'switch', 'case', 'default', 'while', 'for', 'break', 'continue', 'return',
				],
				effects: [
					'try', 'with', 'handle', 'use', 'throw', 'catch',
				],
				async: [
					'async', 'await',
				],
				object: [
					'enum', 'struct', 'function',
				],
				type: [
					'let', 'symbol', 'boolean', 'int', 'float', 'string', 'char', 'func',
				],
				module: [
					'import', 'from', 'as', 'export', 'default',
				],
				'undefined': [
					'undefined',
				],
			})
		},
		control: [
			'if', 'else', 'do', 'switch', 'case', 'default', 'while', 'for', 'break', 'continue', 'return',
		],
		effects: [
			'handle', 'with', 'catch', 'use',
		],
		async: [
			'async', 'await',
		],
		object: [
			'enum', 'struct', 'function',
		],
		type: [
			'let', 'symbol', 'boolean', 'int', 'float', 'string', 'char', 'func',
		],
		module: [
			'import', 'from', 'as', 'export', 'default',
		],
		'undefined': [
			'undefined',
		],
		break: ';',
	},
	str_lit: {
		interp: { match: '${', push: 'main' },
		escape: /\\./,
		lit_str_end: { match: '`', pop: true },
		str_content: { match: /(?:[^$`\\])+/, lineBreaks: true },
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