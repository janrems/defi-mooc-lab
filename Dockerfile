FROM node:18

WORKDIR /lab2

# Copy repo contents and patch files
COPY . .

# Install deps and patch Hardhat to tolerate missing totalDifficulty in forked blocks
RUN npm install && node -e "const fs=require('fs');\
const edits=[\
  {path:'node_modules/hardhat/internal/core/jsonrpc/types/output/block.js',find:'totalDifficulty: base_types_1.rpcQuantity,',rep:'totalDifficulty: (0, io_ts_1.optional)(base_types_1.rpcQuantity),'},\
  {path:'node_modules/hardhat/src/internal/core/jsonrpc/types/output/block.js',find:'totalDifficulty: base_types_1.rpcQuantity,',rep:'totalDifficulty: (0, io_ts_1.optional)(base_types_1.rpcQuantity),'},\
  {path:'node_modules/hardhat/internal/hardhat-network/provider/BlockchainBase.js',find:'const parentTD = this._data.getTotalDifficulty(parentHash);\\n        (0, errors_1.assertHardhatInvariant)(parentTD !== undefined, \"Parent block should have total difficulty\");\\n        return parentTD + difficulty;',rep:'const parentTD = this._data.getTotalDifficulty(parentHash);\\n        const parentTotalDifficulty = parentTD !== undefined ? parentTD : 0n;\\n        return parentTotalDifficulty + difficulty;'},\
  {path:'node_modules/hardhat/src/internal/hardhat-network/provider/BlockchainBase.js',find:'const parentTD = this._data.getTotalDifficulty(parentHash);\\n        (0, errors_1.assertHardhatInvariant)(parentTD !== undefined, \"Parent block should have total difficulty\");\\n        return parentTD + difficulty;',rep:'const parentTD = this._data.getTotalDifficulty(parentHash);\\n        const parentTotalDifficulty = parentTD !== undefined ? parentTD : 0n;\\n        return parentTotalDifficulty + difficulty;'}\
];\
edits.forEach(({path,find,rep})=>{if(fs.existsSync(path)){let s=fs.readFileSync(path,'utf8');if(s.includes(find)){fs.writeFileSync(path,s.replace(find,rep));}}});\
const clientPaths=['node_modules/hardhat/internal/hardhat-network/jsonrpc/client.js','node_modules/hardhat/src/internal/hardhat-network/jsonrpc/client.js'];\
clientPaths.forEach(path=>{if(!fs.existsSync(path)) return; let src=fs.readFileSync(path,'utf8');\
  const hook='const rawResult = await this._send(method, params);\\n        const decodedResult = (0, decodeJsonRpcResponse_1.decodeJsonRpcResponse)(rawResult, tType);';\
  const inject='const rawResult = await this._send(method, params);\\n        if(rawResult && rawResult.result && rawResult.result.totalDifficulty === undefined && (method === \"eth_getBlockByNumber\" || method === \"eth_getBlockByHash\")) { rawResult.result.totalDifficulty = \"0x0\"; }\\n        const decodedResult = (0, decodeJsonRpcResponse_1.decodeJsonRpcResponse)(rawResult, tType);';\
  if(src.includes(hook)){src=src.replace(hook,inject);}\
  const bHook='const rawResults = await this._sendBatch(batch);\\n        const decodedResults = rawResults.map((result, i) => (0, decodeJsonRpcResponse_1.decodeJsonRpcResponse)(result, batch[i].tType));';\
  const bInject='const rawResults = await this._sendBatch(batch);\\n        rawResults.forEach((r,i)=>{const m=batch[i].method; if(r && r.result && r.result.totalDifficulty === undefined && (m === \"eth_getBlockByNumber\" || m === \"eth_getBlockByHash\")) { r.result.totalDifficulty = \"0x0\"; }});\\n        const decodedResults = rawResults.map((result, i) => (0, decodeJsonRpcResponse_1.decodeJsonRpcResponse)(result, batch[i].tType));';\
  if(src.includes(bHook)){src=src.replace(bHook,bInject);}\
  fs.writeFileSync(path,src);\
});"
