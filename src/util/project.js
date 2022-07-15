const { exists, read_file, write_file } = require('./files')
const path = require('path')
const user = require('./user')

let usingSyncWrites = false
let writeIndex = 0
let writePoint = 0
// hack because js doesn't have algebraic effects
exports.useConfig = async (contents) => {
    usingSyncWrites = true
    try {
        writePoint = 0
        await contents()
    }
    catch (prom) {
        if (!prom instanceof Promise)
            throw prom
        writeIndex++
        await prom
    }
    writeIndex = 0
    usingSyncWrites = false
}

let proxy_object = (object, update) => {
    return new Proxy(object, {
        get(target, property){
            let value = target[property]
            if (typeof value !== 'object')
                return value
            return proxy_object(value, update)
        },
        set(target, property, value){
            writePoint++
            if(writePoint > writeIndex)
                target[property] = value
                if(usingSyncWrites)
                    throw update()
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
            return write_file(file_path, JSON.stringify(data, null, '\t'))
        })
    }
}

exports.config = new Proxy({}, {
    async get(_, property) {
        switch (property) {
            case "manifest":
            case "development":
            case "collider":
                return await load_file(`${property}.json`)
        }
    },
})

exports.directory = get_dir

exports.is_valid_project = is_valid_project
