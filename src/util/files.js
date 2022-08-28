const fs = require('fs')
const path = require('path')
const zlib = require('zlib')
const https = require('https')

const exists = async (file) => {
    return await fs.promises.access(file, fs.constants.F_OK)
        .then(() => true)
        .catch(() => false)
}

const is_dir = async (location) => {
    return await fs.promises.lstat(location).isFile()
}

const list_dir = async (location) => {
    return await fs.promises.readdir(location)
}

const mkdir = async (dir) => {
    return await fs.promises.mkdir(dir, { recursive: true })
}

const read_file = async (file) => {
    return await fs.promises.readFile(
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

const delete_file = async (file) => {
    return await fs.promises.unlink(file)
}

const create_read_stream = (...args) => {
    return fs.createReadStream(...args)
}

const download = async (url, output) => {
    try {
        const file_stream = fs.createWriteStream(output)
        const gz = zlib.createGzip()
        await new Promise((resolve, reject) => {
            gz.on('finish', resolve)
            gz.on('error', reject)

            gz.pipe(file_stream)
            https.get(url, res => res.pip(gz))
        })
        gz.end()
        return true
    }
    catch {
        return false
    }
}

const rename = async (from, to) => {
    return await fs.promises.rename(from, to)
}

module.exports = {
    exists,
    is_dir,
    list_dir,
    mkdir,
    read_file,
    write_file,
    delete_file,
    create_read_stream,
    download,
    rename,
}