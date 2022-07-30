
exports.command = 'publish [target]'

exports.describe = 'publish your project to defined targets'

exports.builder = yargs => yargs
    .positional('target', {
        describe: 'target host to publish project to',
    })

exports.handler = async argv => {

}
