export class RouteError extends Error {
  constructor(status, code) { super(code); this.status = status; }
}
const definitions = {
  openai: {url:'https://api.openai.com/v1/responses', paid:true, capabilities:['chat','code','reasoning','long']},
  gemini: {url:'https://generativelanguage.googleapis.com/v1beta/models/', paid:false, capabilities:['chat','code','reasoning','long']},
  groq: {url:'https://api.groq.com/openai/v1/chat/completions', paid:false, capabilities:['chat','code']},
};
export function providersFromEnv(env) {
  return Object.entries(definitions).flatMap(([id, definition]) => {
    const key = env[`${id.toUpperCase()}_API_KEY`];
    const model = env[`${id.toUpperCase()}_MODEL`];
    return key && model ? [{id, ...definition, key, model,
      paid: env[`${id.toUpperCase()}_PAID`] === 'true' || definition.paid,
      dailyLimit: positiveInt(env[`${id.toUpperCase()}_DAILY_LIMIT`], 100)}] : [];
  });
}
export function positiveInt(value, fallback) {
  if (value === undefined) return fallback;
  const n = Number(value);
  if (!Number.isSafeInteger(n) || n < 1) throw new Error('Invalid positive integer configuration');
  return n;
}
export function validate(body) {
  if (!body || typeof body.prompt !== 'string' || !body.prompt.trim() || body.prompt.length > 12000)
    throw new RouteError(400,'invalid_prompt');
  const history = body.history ?? [];
  if (!Array.isArray(history) || history.length > 12 || history.some(m =>
    !m || !['user','assistant'].includes(m.role) || typeof m.content !== 'string' || m.content.length > 4096))
    throw new RouteError(400,'invalid_history');
  if (body.provider !== undefined && !['auto', ...Object.keys(definitions)].includes(body.provider))
    throw new RouteError(400,'invalid_provider');
  return {prompt:body.prompt, history, provider:body.provider ?? 'auto'};
}
export function classify(prompt, history) {
  if (prompt.length + history.reduce((n,m)=>n+m.content.length,0) > 8000) return 'long';
  if (/código|codigo|flutter|debug|programa|function|sql|python|javascript/i.test(prompt)) return 'code';
  if (/analise|análise|compare|demonstre|racioc|matem|passo a passo/i.test(prompt)) return 'reasoning';
  return 'chat';
}
export class Router {
  constructor(providers, {fetchImpl=fetch, now=Date.now, allowPaid=false}={}) {
    this.providers=providers; this.fetch=fetchImpl; this.now=now; this.allowPaid=allowPaid;
    this.usage=new Map(); this.cooldown=new Map();
  }
  async answer(raw) {
    const request=validate(raw), task=classify(request.prompt,request.history);
    const order = {chat:['groq','gemini','openai'],code:['openai','gemini','groq'],reasoning:['openai','gemini'],long:['gemini','openai']}[task];
    const eligible=this.providers.filter(p=>p.capabilities.includes(task) && (!p.paid || this.allowPaid));
    if (request.provider !== 'auto' && !eligible.some(p=>p.id===request.provider))
      throw new RouteError(422,'provider_unavailable_or_incompatible');
    eligible.sort((a,b)=>order.indexOf(a.id)-order.indexOf(b.id));
    if(request.provider!=='auto') eligible.sort((a,b)=>Number(b.id===request.provider)-Number(a.id===request.provider));
    const attempts=[];
    for (const p of eligible) {
      const day=new Date(this.now()).toISOString().slice(0,10);
      const record=this.usage.get(p.id);
      const count=record?.day===day ? record.count : 0;
      if(count>=p.dailyLimit || (this.cooldown.get(p.id)??0)>this.now()) continue;
      // Reserve before awaiting, including failed calls, to bound concurrent spending.
      this.usage.set(p.id,{day,count:count+1}); attempts.push(p.id);
      try {
        const text=await this.call(p,request);
        return {text,provider:p.id,model:p.model,task,fallback:attempts.length>1};
      } catch(error) {
        if(error instanceof RouteError && error.status===403) throw new RouteError(422,'provider_refused');
        const seconds=error.retryAfter ?? (error.status===401 ? 300 : 30);
        this.cooldown.set(p.id,this.now()+seconds*1000);
        if(error instanceof RouteError && error.status===400) throw new RouteError(422,'provider_rejected_request');
      }
    }
    throw new RouteError(503,'no_provider_available');
  }
  async call(p,{prompt,history}) {
    const system='Você é Kay. Responda em português do Brasil, de forma breve e natural, adequada para fala.';
    const messages=[{role:'system',content:system},...history,{role:'user',content:prompt}];
    let url=p.url, headers={'content-type':'application/json',authorization:`Bearer ${p.key}`}, body;
    if(p.id==='openai') body={model:p.model,input:messages,max_output_tokens:512,store:false};
    else if(p.id==='gemini') {
      url+=`${encodeURIComponent(p.model)}:generateContent`;
      headers={'content-type':'application/json','x-goog-api-key':p.key};
      body={systemInstruction:{parts:[{text:system}]},contents:messages.slice(1).map(m=>({role:m.role==='assistant'?'model':'user',parts:[{text:m.content}]})),generationConfig:{maxOutputTokens:512}};
    } else body={model:p.model,messages,max_tokens:512,stream:false};
    const response=await this.fetch(url,{method:'POST',headers,body:JSON.stringify(body),signal:AbortSignal.timeout(12000),redirect:'error'});
    if(!response.ok) {
      const error=new RouteError(response.status,'upstream_error');
      const retry=response.headers.get('retry-after');
      if(retry) error.retryAfter=Math.min(3600,Math.max(1,Number(retry)||Math.ceil((Date.parse(retry)-this.now())/1000)||30));
      throw error;
    }
    const data=await response.json();
    if(data.promptFeedback?.blockReason || data.candidates?.some(c=>['SAFETY','PROHIBITED_CONTENT'].includes(c.finishReason)) || data.output?.some(o=>o.content?.some(c=>c.type==='refusal')) || data.choices?.some(c=>c.message?.refusal || c.finish_reason==='content_filter'))
      throw new RouteError(403,'refused');
    const text=p.id==='openai' ? data.output?.flatMap(o=>o.content??[]).filter(c=>c.type==='output_text').map(c=>c.text).join('')
      :p.id==='gemini' ? data.candidates?.[0]?.content?.parts?.map(p=>p.text??'').join('') :data.choices?.[0]?.message?.content;
    if(typeof text!=='string' || !text.trim()) throw new RouteError(502,'empty_response');
    return text.trim();
  }
}
