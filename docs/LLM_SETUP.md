# IA com OpenAI, Gemini e Groq

## Arquitetura e comportamento

`KayController → AiService → ProxyAiService → backend/server.mjs → Router → provedor`.
Comandos locais continuam no `CommandRouter`, antes da IA. A memória recente existente
é enviada apenas quando uma pergunta chega à IA. O serviço nativo Android continua
restrito aos comandos locais; esta integração atende conversas iniciadas pelo Flutter.
Com nuvem desativada, o app usa Ollama e agora respeita URL/modelo das configurações.
Não há fallback silencioso entre Ollama e nuvem.

O roteamento é uma heurística previsível, não uma garantia de melhor resposta:

| Pergunta | Preferência automática |
| --- | --- |
| Conversa curta | Groq → Gemini → OpenAI |
| Código/Flutter/debug | OpenAI → Gemini → Groq |
| Análise, comparação, matemática | OpenAI → Gemini |
| Contexto acima de 8.000 caracteres | Gemini → OpenAI |

A seleção considera disponibilidade das chaves/modelos, capacidade declarada,
política de custo, limite diário e cooldown. A escolha manual prioriza o provedor;
em erro, pode usar outro compatível. Provedor manual ausente, bloqueado por custo
ou incompatível retorna 422. Configure modelos de texto capazes das tarefas
declaradas em `backend/router.mjs`; alterar o modelo exige revisar essas capacidades.
São três provedores nesta versão, dentro do limite de até cinco solicitado.
Não há busca na internet, anexos, áudio bruto nem ferramentas remotas. A voz
continua sendo transcrita pelo app; o roteador recebe texto.

## 1. Obter chaves (somente no servidor)

Pesquisa conferida em 21/10/2026 na lista
[Free LLM APIs](https://github.com/mnfst/awesome-free-llm-apis).
Groq foi escolhido como terceira opção por oferecer camada gratuita de inferência
de texto, com [limites publicados](https://console.groq.com/docs/rate-limits).
Limites/modelos podem mudar: a conta de cada provedor é a referência final.

- **OpenAI:** crie uma chave de projeto no painel de API, seguindo o
  [guia oficial](https://developers.openai.com/api/docs/quickstart).
  Escolha um modelo de texto disponível para sua conta no
  [catálogo](https://developers.openai.com/api/docs/models), com suporte a Responses.
  Preencha `OPENAI_API_KEY` e `OPENAI_MODEL`. Configure faturamento/limites no painel.
  A integração usa Responses com `store:false`. OpenAI fica desativada enquanto
  `ALLOW_PAID=false`, mesmo se houver chave.
- **Google Gemini:** gere a chave no [AI Studio](https://aistudio.google.com/apikey).
  Preencha `GEMINI_API_KEY` e `GEMINI_MODEL` com um modelo de texto acessível
  por `generateContent`. Confira a [API REST](https://ai.google.dev/api/generate-content)
  e a [tabela de preços](https://ai.google.dev/gemini-api/docs/pricing) para selecionar
  um modelo com free tier na sua conta. O plano gratuito pode usar conteúdo para
  melhorar os produtos Google; evite dados sensíveis.
- **Groq:** gere a chave em [API Keys](https://console.groq.com/keys), seguindo o
  [quickstart](https://console.groq.com/docs/quickstart). Preencha `GROQ_API_KEY` e
  `GROQ_MODEL`. Exemplo listado atualmente: `openai/gpt-oss-20b`;
  confirme disponibilidade no [catálogo](https://console.groq.com/docs/models).

Não envie chaves no chat nem as cole no app. Não use `--dart-define` para segredos.
Modelos ficam explicitamente configurados para não depender de aliases retirados.
Se Gemini/Groq tiverem faturamento habilitado, marque `GEMINI_PAID=true` /
`GROQ_PAID=true`. `ALLOW_PAID` é uma trava de configuração, não detecta a cobrança
real da conta. Use os controles de gastos de cada provedor.

## 2. Iniciar o proxy no computador

Instale Node.js 22 ou superior. Na raiz do repositório, no PowerShell:

```powershell
cd backend
Copy-Item .env.example .env
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
```

Copie o valor gerado para `KAY_PROXY_TOKEN` em `backend/.env`. Preencha as chaves
e modelos desejados no mesmo arquivo. Chave ou modelo vazio desabilita aquele
provedor. Para testar **os três**, configure os três e ajuste `ALLOW_PAID=true`
apenas após configurar seus limites de gastos. Em seguida:

```powershell
npm test
npm start
```

Diagnósticos opcionais na pasta `backend`: `npm run check:providers` verifica
autenticação/listagem de modelos; `npm run smoke:providers` faz uma chamada real
curta por provedor configurado, sem fallback, para não mascarar falhas. O segundo
pode consumir créditos. Os scripts não imprimem chaves nem erros brutos.
Uma listagem de modelos bem-sucedida não garante saldo ou permissão para gerar respostas.

O servidor escuta apenas `127.0.0.1:8787`, não registra prompts/chaves nem retorna
erros brutos dos provedores. Não precisa instalar pacotes externos.
O token do proxy é uma credencial pessoal distinta das chaves dos provedores;
gere outro se ele vazar. O `.env` é ignorado pelo Git.

## 3. Android por USB (teste sem hospedagem)

Com Flutter instalado e depuração USB ativada:

```powershell
git switch feat/llm-provider-router
flutter pub get
flutter analyze
flutter test
adb devices
adb reverse tcp:8787 tcp:8787
flutter run
```

No Kay, abra **Configurações → IA**:

1. Em endereço do proxy, informe `http://127.0.0.1:8787`.
2. No token do proxy, cole **somente** o valor de `KAY_PROXY_TOKEN`.
3. Toque **Salvar proxy**, escolha **Automático** e ative **Usar IA na nuvem**.
4. Fale uma pergunta aberta, por exemplo: “Explique por que o céu é azul”.
5. Selecione Gemini, Groq e OpenAI individualmente e repita a pergunta.
   OpenAI requer `ALLOW_PAID=true`. O token precisa ser informado novamente após
   reiniciar o processo do app; ele fica apenas em memória.

HTTP local é permitido apenas em builds debug. O encaminhamento USB precisa ser
refeito após desconectar. No emulador, também é possível usar `http://10.0.2.2:8787`.
Para APK release ou acesso fora do computador, hospede o proxy atrás de HTTPS com
certificado válido. Use um terminador TLS, configure `HOST` conforme a infraestrutura
e exponha apenas o acesso HTTPS autenticado. Nunca exponha diretamente HTTP com o token.
Este proxy é pessoal, com um token; distribuição multiusuário exige autenticação
individual, quotas persistentes por usuário e armazenamento seguro das sessões.

## 4. Verificar o provedor escolhido e fallback

Para ver metadados sem depender da voz, em outro terminal na pasta `backend`:

```powershell
$kayToken = Read-Host 'Token pessoal do proxy'
$kayHeaders = @{ Authorization = "Bearer $kayToken" }
Invoke-RestMethod http://127.0.0.1:8787/v1/chat -Method Post -Headers $kayHeaders -ContentType 'application/json; charset=utf-8' -Body '{"prompt":"Oi Kay","provider":"auto"}'
```

A resposta inclui `text`, `provider`, `model`, `task` e `fallback`. Repita com
`provider` igual a `openai`, `gemini` e `groq` para conferir cada integração.
Para testar fallback sem gastar quota, use `npm test`; os testes simulam 429,
falhas de rede, modelo inexistente, credencial inválida, respostas malformadas e
limites. Para conferir a configuração real, desative temporariamente um provedor
(remova sua chave no `.env`, reinicie) e teste o modo automático.

São no máximo três tentativas, uma por provedor, com timeout de 12 segundos cada.
429 respeita `Retry-After`; falhas recebem cooldown. Recusas de segurança e
requisições inválidas interrompem o fluxo. Contadores diários reservam uma tentativa
antes da chamada, inclusive falhas, e reiniciam às 00h UTC. Eles e o cooldown são
**em memória** e zeram ao reiniciar o servidor; não são um teto monetário persistente.
Há limite global por minuto e quatro chamadas simultâneas. Erros 401 indicam token
do proxy; 422 indica seleção incompatível/bloqueio/rejeição; 429 indica limite local;
503 indica ausência de provedor elegível ou todos temporariamente indisponíveis.

## Validação e limitações

`node --test` verifica roteamento, adaptadores e a fronteira HTTP com provedores
simulados. `test/proxy_ai_service_test.dart` cobre integração do cliente Flutter,
histórico, token não persistido e erros. Execute a suíte Flutter e teste em Android
com o SDK local. Chamadas reais exigem suas credenciais e podem gerar custos;
nenhuma credencial foi inventada ou adicionada ao repositório.
