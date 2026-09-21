# Kay

<p align="center">
  <strong>Um assistente pessoal de voz para Android, inspirado no Jarvis.</strong><br>
  <sub>Calmo na interface. Local na inteligência. Preparado para evoluir.</sub>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/status-em%20desenvolvimento-183B56?style=for-the-badge" alt="Status: em desenvolvimento">
  <img src="https://img.shields.io/badge/plataforma-Android-183B56?style=for-the-badge" alt="Plataforma Android">
  <img src="https://img.shields.io/badge/licen%C3%A7a-propriet%C3%A1ria-183B56?style=for-the-badge" alt="Licença proprietária">
</p>

## Sobre o projeto

O Kay transforma comandos de voz em ações no celular. Ele pode ser ativado por “Kay”, ouvir comandos em português, responder usando uma IA local e abrir aplicativos mesmo quando a interface principal está minimizada.

O projeto usa Flutter para a experiência mobile e componentes nativos do Android para voz, assistente padrão, notificações e execução em segundo plano.

## O que já funciona

- Ativação por “Kay” com detector local Vosk.
- Assistente padrão do Android via `VoiceInteractionService`.
- Comandos em português para abrir YouTube, Spotify, Chrome e Configurações.
- Funcionamento em segundo plano com notificação persistente.
- Respostas de data, hora, dia da semana e amanhã pelo relógio do celular.
- Perguntas abertas usando Ollama e `llama3.2:3b`.
- Memória curta de até seis trocas, com expiração após 15 minutos.
- Cancelamento da escuta, processamento e fala.
- Espera configurável para o usuário começar a falar.
- Escolha de voz, tom mais grave e prévia no aparelho.
- Interface escura, futurista e confortável para os olhos.
- Painel de conversa, permissões, status e configurações.

## Visão do produto

```text
Celular Android
      │
      ├── Interface Flutter
      ├── Voz, TTS e memória curta
      └── Serviços nativos Android
              │
              └── Ollama local ou futura VPS
```

## Executar no Android

Na pasta do projeto:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d <ID_DO_APARELHO> --dart-define=KAY_AI_URL=http://SEU_IP:11434
```

Para gerar o APK:

```powershell
flutter build apk --debug --dart-define=KAY_AI_URL=http://SEU_IP:11434
```

O arquivo será gerado em `build/app/outputs/flutter-apk/app-debug.apk`.

## IA local com Ollama

O Kay pode conversar com um Ollama executando no computador ou em uma futura VPS. O servidor precisa estar acessível pelo celular e não deve ser exposto diretamente à internet sem autenticação e HTTPS.

```powershell
ollama pull llama3.2:3b
ollama serve
```

Na rede local, compile apontando `KAY_AI_URL` para o IP do computador. A migração para uma VPS Oracle Cloud e um modelo melhor está no roadmap.

## Roadmap

- [x] Base visual, voz e comandos locais.
- [x] Ativação por “Kay” e operação em segundo plano.
- [x] Integração com Ollama.
- [x] Memória curta, data/hora, cancelamento e erros claros.
- [x] Interface mobile com abas, configurações e status.
- [ ] VPS gratuita ou de baixo custo para a IA.
- [ ] Modelo melhor para português e conexão segura com backend.
- [ ] Agente Kai para Windows.
- [ ] Controle autorizado de computadores e integração com AnyDesk.

## Segurança

Não coloque chaves, tokens, senhas, dados da Oracle, IPs públicos ou arquivos pessoais neste repositório. Consulte o [LICENSE](LICENSE) e o [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) antes de redistribuir qualquer parte do projeto.

## Licença

O Kay é um projeto proprietário. Todos os direitos são reservados por Rosen. Consulte o arquivo [LICENSE](LICENSE).

## Estado atual

O projeto está em desenvolvimento ativo. A Sprint 9 foi implementada com 80 testes aprovados e APK compilado. A validação visual final da nova interface deve ser feita no aparelho Android conectado.
