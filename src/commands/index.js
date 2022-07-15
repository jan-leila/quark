
const interactive = require('./interactive')
const init = require('./init')
const build = require('./build')
const start = require('./start')
const run = require('./run')
const source = require('./source')
const alias = require('./alias')
const install = require('./install')

module.exports = yargs => yargs
    .command(interactive)
    .command(init)
    .command(build)
    .command(start)
    .command(run)
    .command(source)
    .command(alias)
    .command(install)
