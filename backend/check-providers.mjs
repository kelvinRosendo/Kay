// Explicit diagnostic: lists model IDs, never prints credentials or raw errors.
const checks = [
  ['openai', 'https://api.openai.com/v1/models', {authorization:`Bearer ${process.env.OPENAI_API_KEY}`}],
  ['gemini', 'https://generativelanguage.googleapis.com/v1beta/models', {'x-goog-api-key':process.env.GEMINI_API_KEY}],
  ['groq', 'https://api.groq.com/openai/v1/models', {authorization:`Bearer ${process.env.GROQ_API_KEY}`}],
];
for (const [provider,url,headers] of checks) {
  try {
    const response=await fetch(url,{headers,signal:AbortSignal.timeout(15000),redirect:'error'});
    const data=await response.json().catch(()=>({}));
    const code=data.error?.code ?? data.error?.status ?? data.error?.type;
    const safeCode=typeof code==='string' && /^[a-zA-Z0-9_]{1,60}$/.test(code) ? code : undefined;
    const models=(data.data??data.models??[]).map(m=>m.id??m.name).filter(m=>typeof m==='string' && /^[a-zA-Z0-9_./:-]{1,100}$/.test(m));
    console.log(JSON.stringify({provider,status:response.status,code:safeCode,models:response.ok?models:undefined}));
  } catch { console.log(JSON.stringify({provider,error:'network_or_timeout'})); }
}
