const path = require('path')
const { is_valid_project } = require('../util/project')
const { write_file } = require('../util/files')
const { current_dir, prompt } = require('../util/user')

exports.command = 'init [folder]'

exports.describe = 'create a new project'

exports.builder = yargs => yargs
    .positional('folder', {
        describe: 'target folder to create project in',
        default: '',
    })
    .option('yes', {
        alias: 'y',
        type: 'boolean',
        description: 'run without a confirmation prompt',
    })
    .option('less', {
        alias: 'l',
        type: 'boolean',
        description: 'run with less prompts',
    })
    .option('entry', {
        alias: 'e',
        type: 'string',
        description: 'entry point to create project with',
    })

exports.handler = async argv => {
    let folder = path.join(current_dir, argv.folder)

    if (await is_valid_project(folder)) {
        console.log('project already exists in this directory');
        return
    }

    if (argv.yes && !await confirm(
        argv.folder ?
            `create project in ${argv.folder}`
            :
            'create project in current directory'
    )) {
        return
    }

    let less = argv.less || argv.yes
    let entry_point = await get_entry_point(less, argv.entry)

    await Promise.all([
        write_file(path.join(folder, 'manifest.json'), JSON.stringify({
            entry_point,
            sources: {},
        }, null, '\t')),
        write_file(path.join(folder, entry_point), '')
    ])
}

const get_entry_point = async (less, kwarg) => {
    if (kwarg) return kwarg
    const default_entry_point = path.join('src', 'index.qk')
    if (less) return default_entry_point
    let entry_point = await prompt(`entry point: (${default_entry_point}) `)
    if (entry_point === '') return default_entry_point
    if (!entry_point.endsWith('.qk')){
        return `${entry_point}.qk`
    }
    return entry_point
}
