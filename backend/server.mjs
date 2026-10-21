import {createServer} from 'node:http';
import {timingSafeEqual} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {Router, RouteError, providersFromEnv, positiveInt} from './router.mjs';

export function createApp({token,router,perMinute=20}) {
  if(!token || token.length<32) throw new Error('KAY_PROXY_TOKEN must contain at least 32 characters');
  let windowStart=0,count=0,active=0;
  return createServer(async(req,res)=>{
    const send=(status,data)=>{res.writeHead(status,{'content-type':'application/json','cache-control':'no-store'});res.end(JSON.stringify(data));};
    const expected=Buffer.from(`Bearer ${token}`), actual=Buffer.from(req.headers.authorization??'');
    if(actual.length!==expected.length || !timingSafeEqual(actual,expected)) return send(401,{error:'unauthorized'});
    if(req.url==='/health' && req.method==='GET') return send(200,{ok:true});
    if(req.url!=='/v1/chat' || req.method!=='POST') return send(404,{error:'not_found'});
    if(Date.now()-windowStart>60000){windowStart=Date.now();count=0;}
    if(++count>perMinute || active>=4) return send(429,{error:'proxy_limit'});
    active++;
    try {
      if(!(req.headers['content-type']??'').startsWith('application/json')) throw new RouteError(415,'json_required');
      let bytes=0; const chunks=[];
      for await(const chunk of req){bytes+=chunk.length;if(bytes>80000) throw new RouteError(413,'body_too_large');chunks.push(chunk);}
      let body;try{body=JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new RouteError(400,'invalid_json');}
      send(200,await router.answer(body));
    }catch(error){send(error instanceof RouteError?error.status:500,{error:error instanceof RouteError?error.message:'internal_error'});}
    finally{active--;}
  });
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
  const router=new Router(providersFromEnv(process.env),{allowPaid:process.env.ALLOW_PAID==='true'});
  const server=createApp({token:process.env.KAY_PROXY_TOKEN,router,perMinute:positiveInt(process.env.RATE_LIMIT,20)});
  server.requestTimeout=15000;server.headersTimeout=10000;
  server.listen(positiveInt(process.env.PORT,8787),process.env.HOST??'127.0.0.1',()=>console.log('Kay proxy ready'));
}
