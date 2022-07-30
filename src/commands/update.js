
exports.command = 'update [target] [version]'

exports.describe = ''

exports.builder = yargs => yargs
    .positional('target', {
        describe: 'target package to upgrade',
    })
    .positional('version', {
        describe: 'target version to upgrade package to',
    })

exports.handler = async argv => {

}
