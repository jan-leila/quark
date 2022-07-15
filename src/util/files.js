const fs = require('fs')
const path = require('path')

const exists = async (file) => {
    return await fs.promises.access(file, fs.constants.F_OK)
        .then(() => true)
        .catch(() => false)
}

const mkdir = async (dir) => {
    return await fs.promises.mkdir(dir, { recursive: true })
}


const read_file = async (file) => {
    return await fs.promises.read_file(
        file,
        {
            encoding: 'utf-8',
        },
    )
}

const write_file = async (file, data) => {
    await mkdir(path.dirname(file))
    return await fs.promises.writeFile(
        file,
        data,
        {
            encoding: 'utf-8',
        },
    )
}

module.exports = {
    exists,
    mkdir,
    read_file,
    write_file,
}