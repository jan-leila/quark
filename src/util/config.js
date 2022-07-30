const os = require('os')
const package_json = require('../../package.json')

exports.artifact = package_json.version

// darwin
// freebsd
// linux
// windows
// android
// web
exports.platform = os.platform() === 'win32' ? 'windows' : os.platform()

// x32
// x64
// arm
// web
exports.architecture = 'x64'

exports.distribution = 'direct'