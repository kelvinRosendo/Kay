import test from 'node:test';
import assert from 'node:assert/strict';
import {Router, providersFromEnv, validate, classify} from './router.mjs';
import {createApp} from './server.mjs';
const env={OPENAI_API_KEY:'fake',OPENAI_MODEL:'test',GEMINI_API_KEY:'fake',GEMINI_MODEL:'test',GROQ_API_KEY:'fake',GROQ_MODEL:'test'};
const providers=()=>providersFromEnv(env);
const ok=id=>new Response(JSON.stringify(id==='openai'?{output:[{content:[{type:'output_text',text:'Olá'}]}]}:id==='gemini'?{candidates:[{content:{parts:[{text:'Olá'}]}}]}:{choices:[{message:{content:'Olá'}}]}));
const idFor=url=>url.includes('googleapis')?'gemini':url.includes('groq')?'groq':'openai';
test('only complete configurations enabled; invalid limits fail closed',()=>{
  assert.equal(providersFromEnv({OPENAI_API_KEY:'fake'}).length,0);
  assert.throws(()=>providersFromEnv({...env,GROQ_DAILY_LIMIT:'NaN'}));
});
test('validation rejects role injection, unknown providers and oversized history',()=>{
  for(const body of [{prompt:''},{prompt:'oi',provider:'unknown'},{prompt:'oi',history:[{role:'system',content:'inject'}]},{prompt:'oi',history:Array(13).fill({role:'user',content:'x'})}]) assert.throws(()=>validate(body));
});
test('classification considers context and Portuguese code/reasoning',()=>{
  assert.equal(classify('código Flutter',[]),'code');
  assert.equal(classify('compare os resultados',[]),'reasoning');
  assert.equal(classify('continue',[{content:'x'.repeat(8001)}]),'long');
});
test('automatic preference, paid opt-in and manual preference',async()=>{
  const r=new Router(providers(),{fetchImpl:async url=>ok(idFor(url))});
  assert.equal((await r.answer({prompt:'oi'})).provider,'groq');
  assert.equal((await r.answer({prompt:'código Flutter'})).provider,'gemini');
  await assert.rejects(r.answer({prompt:'oi',provider:'openai'}),{status:422});
  r.allowPaid=true;
  assert.equal((await r.answer({prompt:'código Flutter'})).provider,'openai');
  assert.equal((await r.answer({prompt:'oi',provider:'gemini'})).provider,'gemini');
  await assert.rejects(r.answer({prompt:'compare resultados',provider:'groq'}),{status:422});
});
test('429 respects retry-after and falls back; resumes after cooldown',async()=>{
  let time=0, groqCalls=0;
  const r=new Router(providers(),{now:()=>time,fetchImpl:async url=>{
    if(idFor(url)==='groq' && ++groqCalls===1) return new Response('',{status:429,headers:{'retry-after':'120'}});
    return ok(idFor(url));
  }});
  assert.equal((await r.answer({prompt:'oi'})).fallback,true);
  assert.equal((await r.answer({prompt:'oi'})).provider,'gemini');
  assert.equal(groqCalls,1);time=121000;
  assert.equal((await r.answer({prompt:'oi'})).provider,'groq');
});
for(const failure of [401,404,500,'network','empty','invalid']) test(`fallback on ${failure}`,async()=>{
  const r=new Router(providers(),{fetchImpl:async url=>{
    if(idFor(url)!=='groq') return ok(idFor(url));
    if(failure==='network') throw new Error('secret must not escape');
    if(failure==='empty') return new Response('{}');
    if(failure==='invalid') return new Response('invalid JSON');
    return new Response('',{status:failure});
  }});
  assert.equal((await r.answer({prompt:'oi'})).provider,'gemini');
});
test('refusal and invalid requests do not bypass provider policies',async()=>{
  for(const response of [new Response('',{status:400}),new Response('',{status:403}),new Response(JSON.stringify({candidates:[{finishReason:'SAFETY'}]}))]) {
    let calls=0;const r=new Router(providers(),{fetchImpl:async()=>{calls++;return response;}});
    await assert.rejects(r.answer({prompt:'oi',provider:'gemini'}),{status:422});assert.equal(calls,1);
  }
});
test('daily budget reserved concurrently; resets on UTC day change',async()=>{
  let time=0;const ps=providers().filter(p=>p.id==='groq');ps[0].dailyLimit=1;
  const r=new Router(ps,{now:()=>time,fetchImpl:async()=>ok('groq')});
  const results=await Promise.allSettled([r.answer({prompt:'oi'}),r.answer({prompt:'oi'})]);
  assert.equal(results.filter(r=>r.status==='fulfilled').length,1);
  time=86400001;assert.equal((await r.answer({prompt:'oi'})).provider,'groq');
});
test('adapters preserve history and keep credentials in headers only',async()=>{
  for(const p of providers()) {
    const r=new Router([p],{allowPaid:true,fetchImpl:async(url,opts)=>{
      assert(!url.includes(p.key));const body=JSON.parse(opts.body);
      assert(!opts.body.includes('fake'));assert.equal(opts.redirect,'error');
      if(p.id==='gemini') {assert.equal(opts.headers['x-goog-api-key'],'fake');assert.equal(body.contents[1].role,'model');}
      else assert.equal(opts.headers.authorization,'Bearer fake');
      return ok(p.id);
    }});
    assert.equal((await r.answer({prompt:'oi',history:[{role:'user',content:'antes'},{role:'assistant',content:'resposta'}]})).text,'Olá');
  }
});
test('HTTP boundary authentication, safe errors, limits and chat',async(t)=>{
  const token='t'.repeat(64);
  const app=createApp({token,router:new Router(providers(),{fetchImpl:async url=>ok(idFor(url))}),perMinute:3});
  await new Promise(resolve=>app.listen(0,'127.0.0.1',resolve));
  t.after(()=>new Promise(resolve=>app.close(resolve)));
  const base=`http://127.0.0.1:${app.address().port}`;
  assert.equal((await fetch(base+'/health')).status,401);
  const headers={authorization:`Bearer ${token}`,'content-type':'application/json'};
  assert.equal((await fetch(base+'/health',{headers})).status,200);
  assert.equal((await fetch(base+'/v1/chat',{method:'POST',headers,body:'{'})).status,400);
  assert.equal((await fetch(base+'/v1/chat',{method:'POST',headers,body:JSON.stringify({prompt:'x'.repeat(81000)})})).status,413);
  assert.equal((await fetch(base+'/v1/chat',{method:'POST',headers,body:'{"prompt":"oi"}'})).status,200);
  assert.equal((await fetch(base+'/v1/chat',{method:'POST',headers,body:'{"prompt":"oi"}'})).status,429);
});
