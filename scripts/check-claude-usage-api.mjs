import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../Sources/TokenMonitorApp/ClaudeUsageAPI.swift', import.meta.url), 'utf8');
const body = source.match(/static let script = #"""([\s\S]*?)"""#/)[1];
assert(!/document\.cookie|localStorage|sessionStorage|Authorization|sessionKey/.test(body));
const id = '00000000-0000-0000-0000-000000000001';
const org = {uuid:id, capabilities:['chat'], name:'PRIVATE_ORG_CANARY', email:'private@example.invalid'};
let checks = 0;
async function run(usage, options = {}) {
  const calls = [];
  const context = vm.createContext({
    location:{origin:(options.protocol ?? 'https:') + '//' + (options.host ?? 'claude.ai') + (options.port ? ':' + options.port : '')},
    AbortController, TextDecoder,
    setTimeout:(fn, delay) => { assert.equal(delay,8000); return setTimeout(fn,options.timeout ? 5 : delay); },
    clearTimeout,
    fetch:async (url, config) => {
      assert.equal(new URL(url).origin, 'https://claude.ai');
      const path = new URL(url).pathname;
      calls.push(path);
      assert.equal(config.credentials,'same-origin'); assert.equal(config.method,'GET');
      assert.equal(config.cache,'no-store'); assert.equal(config.redirect,'error');
      assert(path === '/api/organizations' || path === `/api/organizations/${id}/usage`);
      if (options.timeout) return new Promise((resolve,reject) => config.signal.addEventListener('abort',() => reject(new Error('PRIVATE_ERROR_CANARY'))));
      const organizations = path === '/api/organizations';
      const status = organizations ? (options.orgStatus ?? 200) : (options.status ?? 200);
      const payload = organizations ? (options.organizations ?? [org]) : usage;
      return new Response(options.oversized && !organizations ? 'x'.repeat(70000) : JSON.stringify(payload), {
        status, headers:{'content-type':options.html && !organizations ? 'text/html' : 'application/json',
          ...(options.challenge ? {'cf-mitigated':'challenge'} : {})}});
    }
  });
  const value = JSON.parse(await new vm.Script(`(async()=>{${body}})()`).runInContext(context));
  assert(calls.length <= 2);
  assert(!JSON.stringify(value).includes(id));
  assert(!/PRIVATE|private@example/.test(JSON.stringify(value)));
  checks++;
  return {value,calls};
}
let read = await run({five_hour:{utilization:12,resets_at:'2026-11-15T12:00:00Z'},seven_day:{utilization:70},private:'PRIVATE_USAGE_CANARY'});
assert.equal(read.value.outcome,'available'); assert.equal(read.value.windows.length,2);
assert.equal(read.value.windows[0].used,12); assert.equal(read.value.windows[0].resetsAt,'2026-11-15T12:00:00.000Z');
for (const key of ['five_hour','seven_day']) {
  read = await run({[key]:{utilization:0}});
  assert.equal(read.value.windows.length,1); assert.equal(read.value.windows[0].scope,key === 'five_hour' ? 'session' : 'weekly');
}
read = await run({five_hour:null,seven_day:null});
assert.equal(read.value.outcome,'notReported'); assert.equal(read.value.confirmedEmpty,true);
assert.equal((await run({five_hour:null,seven_day:null}, {organizations:[{...org,capabilities:[]}]})).value.outcome,'notReported');
for (const payload of [{},{five_hour:null},{five_hour:null,seven_day:null,error:'PRIVATE_ERROR'},[],{five_hour:true},{five_hour:{utilization:true}},
    {five_hour:{utilization:-1}},{seven_day:{utilization:101}},{seven_day:{utilization:4,resets_at:'PRIVATE_DATE'}}]) {
  assert.equal((await run(payload)).value.outcome,'invalidResponse');
}
for (const [status,outcome] of [[401,'unauthorized'],[403,'forbidden'],[429,'rateLimited'],[500,'invalidResponse']]) {
  read = await run({}, {status}); assert.equal(read.value.outcome,outcome); assert.equal(read.value.httpStatus,status);
}
assert.equal((await run({}, {orgStatus:401})).calls.length,1);
assert.equal((await run({}, {challenge:true})).value.outcome,'challenge');
assert.equal((await run({}, {organizations:[org,{...org,uuid:'00000000-0000-0000-0000-000000000002'}]})).value.outcome,'ambiguousWorkspace');
assert.equal((await run({}, {organizations:[{...org,capabilities:['api']}]})).value.outcome,'noWorkspace');
assert.equal((await run({}, {organizations:[org,{uuid:'INVALID_ID',capabilities:['chat']}]})).value.outcome,'invalidResponse');
read = await run({five_hour:{utilization:80}}, {organizations:[{...org,capabilities:['api']},org]});
assert.equal(read.value.outcome,'available');
for (const options of [{host:'claude.ai.attacker.invalid'},{protocol:'http:'},{port:'444'}]) {
  read = await run({},options); assert.equal(read.value.outcome,'untrustedOrigin'); assert.equal(read.calls.length,0);
}
assert.equal((await run({}, {html:true})).value.outcome,'invalidResponse');
assert.equal((await run({}, {oversized:true})).value.outcome,'invalidResponse');
assert.equal((await run({}, {timeout:true})).value.outcome,'timedOut');
console.log(`PASS: ${checks} Claude API fixtures; bounded same-origin reads, schema, isolation, empty limits and private projection`);
