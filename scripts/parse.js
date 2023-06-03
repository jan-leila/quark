const fs = require('fs');
const util = require('util');
const parser = require('../src/engine/parser.js');

const file = fs.readFileSync('examples/example-project/index.qk', "utf-8");
parser.feed(file);

// console.log("-------------------------------");
// console.log(util.inspect(parser.results, { showHidden: false, depth: null, colors: true }));

const differences_recursion = (object_1, object_2, path) => {
  return [
    ...Object.keys(object_1),
    ...Object.keys(object_2),
  ]
  .filter((key, i, keys) => {
    return keys.indexOf(key) === i
  })
  .map((key) => {
    const next_path = [...path, key]
    if (typeof object_1[key] === 'object' && object_1[key] !== null) {
      if (typeof object_2[key] === 'object' && object_2[key] !== null) {
        return differences_recursion(object_1[key], object_2[key], next_path)
      }
    }
    if (object_1[key] !== object_2[key]) {
      return [{
        path: next_path, object_1: object_1[key], object_2: object_2[key] }]
    }
    return []
  }).flat()
}

const differences = (object_1, object_2) => {
  return differences_recursion(object_1, object_2, []).map(({ path, ...rest }) => {
    return { path: Array.from(path).join('.'), ...rest }
  })
}

// if (parser.results.length > 1) {
//   parser.results.slice(1).forEach((results) => {
//     console.log(util.inspect(differences(parser.results[0], results), { showHidden: false, depth: null, colors: true }));
//   })
// }

console.log(util.inspect(parser.results[0], { showHidden: false, depth: null, colors: true }));
// parser.results[1] && console.log(util.inspect(parser.results[1], { showHidden: false, depth: null, colors: true }));
console.log(parser.results.length);
