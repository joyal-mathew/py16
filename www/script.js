(() => {
    "use strict";

    const assembleButton = document.getElementById("assemble");
    const runButton = document.getElementById("run");

    const programArea = document.getElementById("program");
    const inputArea = document.getElementById("input");
    const outputArea = document.getElementById("output");
    const msgArea = document.getElementById("messages");

    const inputs = [];

    const encoder = new TextEncoder();
    const decoder = new TextDecoder();

    let len = null;
    let ptr = null;
    let org = null;

    let result;

    WebAssembly.instantiateStreaming(fetch("www/main.wasm"), {
        env: {
            memory: new WebAssembly.Memory({ initial: 1 }),
            input: () => (+inputs.shift() || 0) & 0xFFFF,
            output: x => outputArea.value += x + "\n",
            err: (ptr, len) => msgArea.value = decoder.decode(new Uint8Array(result.instance.exports.memory.buffer).subarray(ptr, ptr + len)),
        }
    }).then(res => {
        result = res;

        assembleButton.onclick = () => {
            const buffer = new Uint8Array(res.instance.exports.memory.buffer);
            const program = encoder.encode(programArea.value + "\nHALT");
            buffer.set(program, 1);

            try {
                const out = res.instance.exports.assemble(1, program.length, 1 + program.length);

                if (out === 0xFFFFFFFF) {
                    return;
                }

                ptr = 1 + program.length;
                len = out >> 16;
                org = out & 0xFFFF;

                msgArea.value = "Assembled";
                inputs.splice(0, inputs.length, ...Uint16Array.from(inputArea.value.split(/\s+/)));
            }
            catch (e) {
                msgArea.value = "[ERROR]: " + e;
            }
        };

        runButton.onclick = () => {
            outputArea.value = "";

            if (org === null || len === null || ptr === null) {
                msgArea.value = "[ERROR]: You must assemble something first";
            }
            else {
                res.instance.exports.run(ptr, len, origin);
            }
        };
    });
})();
