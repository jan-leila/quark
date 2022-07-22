const fs = require('fs');
const util = require('util');
const parser = require('../src/engine/parser.js');

let file = fs.readFileSync('examples/index.qk', "utf-8");
parser.feed(file);

console.log(util.inspect(parser.results[0], { showHidden: false, depth: null, colors: true }));
