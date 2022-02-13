const fs = require('fs');
const util = require('util');

const nearley = require("nearley");
const grammar = require("./grammar.js");

// Create a Parser object from our grammar.
const parser = new nearley.Parser(nearley.Grammar.fromCompiled(grammar));

let file = fs.readFileSync('index.qk', "utf-8");
parser.feed(file);

// console.log(util.inspect(parser.results[0], { showHidden: false, depth: null, colors: true }));