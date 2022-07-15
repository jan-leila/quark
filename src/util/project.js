const { exists, read_file, write_file } = require('./files')
const path = require('path')
const user = require('./user')

let proxy_object = (object, update) => {
    return new Proxy(object, {
        get(target, property){
            return proxy_object(target[property], root)
        },
        set(target, property, value){
            target[property] = value
            update()
        }
    })
}

const is_valid_project = async (dir) => {
    return await exists(path.join(dir, 'manifest.json'))
    // TODO: add more checks here
}

let project_dir = user.current_dir
const get_dir = async () => {
    do {
        if (await is_valid_project(project_dir))
            return project_dir
        project_dir = path.dirname(project_dir)
    } while (project_dir !== '/')
    return undefined
}

const files = {}
const load_file = async (file) => {
    if (files[file])
        return files[file]
    
    let dir = await get_dir()
    if (dir){
        let file_path = path.join(dir, file)
        let data = JSON.parse(await read_file(file_path))
        return files[file] = proxy_object(data, () => {
            write_file(file_path, JSON.stringify(data))
        })
    }
}

exports.config = new Proxy({}, {
    async get(_, property) {
        switch (property) {
            case "manifest":
            case "development":
            case "collider":
                return await load_file(property)
        }
    },
})

exports.directory = get_dir

exports.is_valid_project = is_valid_project
