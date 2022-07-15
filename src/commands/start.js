const path = require('path')
const project = require('../util/project')

exports.command = 'start [file]'

exports.describe = 'run quark with target file as main'

exports.builder = yargs => yargs
    .positional('file', {
        describe: 'target file to run from',
        default: async () => (await project.config.manifest).entry_point,
    })
    .middleware(async argv => argv.file = await argv.file)

exports.handler = async argv => {
    return await start(argv)
}

const start = async (argv) => {
    let entry_point = argv.file
    if (entry_point === undefined) {
        console.log('no entry point provided');
        return
    }
    let file = path.join(await project.directory(), entry_point)
    console.log(file);
}

exports.start = start