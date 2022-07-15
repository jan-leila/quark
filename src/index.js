#!/usr/bin/node
const yargs = require('yargs')
const { hideBin } = require('yargs/helpers')

const commands = require('./commands')

const { artifact } = require('./util/config')

!(async () => {
    try {
        await commands(yargs(hideBin(process.argv)))
            .alias('v', 'version')
            .alias('h', 'help')
            .version(`collider ${artifact}`)
            .parse()
    }
    catch (err) {
        process.exit(err)
    }
    process.exit()
})()
