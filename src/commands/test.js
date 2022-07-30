
exports.command = 'test [target]'

exports.describe = 'run project tests'

exports.builder = yargs => yargs
    .positional('target', {
        describe: 'target test file to run',
    })

exports.handler = async argv => {

}
