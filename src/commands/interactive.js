const { prompt } = require('../util/user')
const { artifact } = require('../util/config')
const { start } = require('./start')

exports.command = '$0 [file]'

exports.describe = 'run in interactive mode or with a target file as main file'

exports.builder = yargs => yargs
    .positional('file', {
        describe: 'target file to run',
    })

exports.handler = async argv => {
    if (argv.file) {
        return await start(argv)
    }

    process.on('beforeExit', () => {
        console.log('');
    })

    console.log(`Quark ${artifact} interactive mode`);

    while (true) {
        let line = await prompt("> ")
        // TODO: feed line to repl
    }
}
