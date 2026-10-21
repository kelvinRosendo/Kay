import {Router,providersFromEnv} from './router.mjs';
const ps=providersFromEnv(process.env);
let failures=0;
for(const p of ps) {
  let upstreamCode;
  const router=new Router([p],{allowPaid:true,fetchImpl:async(url,options)=>{
    const response=await fetch(url,options);
    if(!response.ok){
      const data=await response.clone().json().catch(()=>({}));
      const code=data.error?.code??data.error?.status??data.error?.type;
      if(typeof code==='string' && /^[a-zA-Z0-9_]{1,60}$/.test(code)) upstreamCode=code;
    }
    return response;
  }});
  try {
    const text=await router.call(p,{prompt:'Responda apenas: Kay conectado.',history:[]});
    console.log(JSON.stringify({provider:p.id,model:p.model,ok:true,text}));
  }catch(error){failures++;console.log(JSON.stringify({provider:p.id,model:p.model,ok:false,status:error.status??null,code:upstreamCode??'request_failed'}));}
}
process.exitCode=failures || ps.length!==3 ? 1 : 0;
