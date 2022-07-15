
exports.command = 'source <alias> <source> [type]'

exports.describe = 'add a package source to your project'

exports.builder = yargs => yargs
    .positional('alias', {
        describe: 'alias for the source',
    })
    .positional('source', {
        describe: 'source for the resource',
    })
    .positional('type', {
        describe: 'the type of the source (will be automatically inferred)',
    })

exports.handler = async argv => {

}
