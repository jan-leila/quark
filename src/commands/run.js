
exports.command = 'run <script>'

exports.describe = 'run a script from development.json'

exports.builder = yargs => yargs
    .positional('script', {
        describe: 'the name of the target script',
    })

exports.handler = async argv => {
    let script = argv.script
}
