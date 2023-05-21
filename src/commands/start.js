const path = require('path')
const project = require('../util/project')
const fs = require('fs');
const parser = require('../engine/parser.js');

exports.command = 'start [file]'

exports.describe = 'run quark with target file as main'

exports.builder = yargs => yargs
    .positional('file', {
        describe: 'target file to run from',
    })
    .middleware(async argv => argv.file = await argv.file)

exports.handler = async argv => {
    return await start(argv)
}

const start = async (argv) => {
    let entry_point = argv.file
    // if (entry_point === undefined) {
    //     entry_point = (await project.config.manifest).entry_point
    //     if(entry_point === ''){
    //         entry_point === undefined
    //     }
    // }
    if (entry_point === undefined) {
        console.log('no entry point provided')
        return
    }

    console.log(entry_point);

    let file = path.join(await project.directory(), entry_point)

    let data = fs.readFileSync(file, "utf-8");
    parser.feed(data);
    console.log(parser.results[0]);
}

exports.start = start