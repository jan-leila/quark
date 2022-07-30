
exports.command = 'upgrade [version]'

exports.describe = ''

exports.builder = yargs => yargs
    .positional('version', {
        describe: 'target version to update project to',
    })

exports.handler = async argv => {

}
