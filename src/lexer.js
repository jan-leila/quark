const moo = require('moo');

let keywords = [
	'import', 'from', 'as', 'export', 'default',
	'if', 'else', 'switch', 'case', 'default', 'do', 'while', 'for', 'break', 'continue', 'return',
	'try', 'with', 'handle', 'use',
	'enum', 'struct', 'function', 'event', 'in', 'out', 'monad', 'bind', 'reduce', 'extends',
	'any', 'symbol', 'boolean', 'int', 'float', 'string', 'char', 'func',
	'null',
];

let assignment = [
	'=??', '=&&', '=||',
	'=<<<', '=>>>', '=<<', '=>>',
	'=&', '=|', '=^',
	'=**', '=%', '=*', '=/', '=+', '=-',
	'=',
];

let misc_tokens = [
	'...',
	'<<<', '>>>',

	'<<=', '>>=',

	'??',
	'==',
	'&&', '||', '<<', '>>',
	'**', '++', '--',

	'=>',
	'/>', '</',
	'!=', '>=', '<=',
	'?.', '?(', '?[',

	'?', ':',
	'.', '(', '[',
	',', '<', '>', ')', ']',
	'!', '~', '&', '|', '^',
	'+', '-', '*', '/', '%',
];


let lexer = moo.states({
	main: {
		whitespace: [/[ \t]+/s, { match: /[ \n\t]+/, lineBreaks: true }],
		comment: [
			/\/\/[^\n]*/,
			{ match: /\/\*[^]*?\*\//, lineBreaks: true },
		],

		binary: /0b[01]+/,
		hex: /0x[0-9a-fA-F]+/,
		int: /[0-9]+(?![0-9]*\.)/,
		float: /(?:0|[1-9][0-9]*)(?:\.[0-9])?[0-9]*/,
		color: [
			/#[0-9a-fA-F]{3}/,
			/#[0-9a-fA-F]{6}/,
			/#[0-9a-fA-F]{8}/,
		],

		string: [
			{ match: /".*?(?<!\\)(?:\\\\)*"/s, lineBreaks: true },
			{ match: /'.*?(?<!\\)(?:\\\\)*'/s, lineBreaks: true }
		],
		template_string_start: { match: '`', push: 'template_string' },

		regex: /\/(?=(?:(?:\\.)?[^\\\/\n]+)+\/)/,

		lcbracket: { match: '{', push: 'main' },
		rcbracket: { match: '}', pop: true },

		misc_tokens: {
			match: misc_tokens,
			type: moo.keywords({
				assignment,
			}),
		},
		assignment,

		identifier: {
			match: /\w+/, type: moo.keywords({
				keywords,
			})
		},
		keywords,
		break: ';',
	},
	template_string: {
		template_string_interpreter: { match: '${', push: 'main' },
		template_string_content: { match: /(?:(?:\\.)+|[^\\$`]+)+/, lineBreaks: true },
		template_string_end: { match: '`', pop: true },
	},
	regex: {
		// TODO: replace with real regex parsing
		regex_content: /(?:(?:\\.)?[^\\\/\n]+)+/,
		// match the end and any flags that go with it,
		regex_end: { match: /\/[gmiy]*/, pop: true },
	}
});

module.exports = {
	next(){
		let token;
		do {
			token = lexer.next()
		} while (token?.type === 'comment');
		return token
	},
	save(){
		return lexer.save();
	},
	reset(chunk, info){
		return lexer.reset(chunk, info);
	},
	formatError(token){
		return lexer.formatError(token);
	},
	has(name){
		return lexer.has(name);
	}
};