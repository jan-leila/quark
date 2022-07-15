const readline = require('readline').createInterface({
    input: process.stdin,
    output: process.stdout,
})

const prompt = (question) => {
    return new Promise((resolve) => {
        readline.question(question, resolve)
    })
}

const confirm = async (question) => {
    do {
        let response = (await prompt(`${question}? (y/n) `)).toLowerCase()
        if (response === 'y' || response === 'yes') {
            return true
        }
        if (response === 'n' || response === 'no') {
            return false
        }
    } while (true)
}

exports.prompt = prompt;

exports.confirm = confirm;

exports.current_dir = process.cwd()
