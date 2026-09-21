# Modelo local para ativação por Kay

Vosk API: Apache-2.0, https://github.com/alphacep/vosk-api
Modelo: vosk-model-small-en-us-0.15, Copyright 2020 Alpha Cephei Inc.
Licença do modelo: Apache-2.0 conforme https://alphacephei.com/vosk/models
Arquivo: https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip
SHA-256 do ZIP: 30f26242c4eb449f948e42cb302dd7a686cb29a3423a8367f99ff41780942498

O README original e a licença Apache-2.0 estão incluídos com o modelo nos assets.
Vosk Android 0.3.75 e JNA 5.18.1 são resolvidos pelo Gradle. JNA é distribuída sob
LGPL-2.1-or-later ou Apache-2.0: https://github.com/java-native-access/jna.

O modelo inglês é usado apenas para o nome Kay/Kai. A transcrição de comandos
continua no serviço de português do Android. A gramática inclui caminhos para
fala desconhecida e OK para reduzir acionamentos indevidos. Não é um modelo
personalizado treinado com a voz do usuário e pode confundir palavras parecidas.

As amostras em test/acoustic foram sintetizadas localmente para validação;
não contêm gravação do microfone do usuário. Teste reproduzível na raiz:

    python -m pip install --target build/wake-validation-tools vosk
    python tools/validate_wake_acoustics.py

O teste usa a lógica de blocos e estabilidade do detector Android. Quatro
amostras de Kay/Kai em inglês/português e seis negativas passaram. Isso não mede
a taxa de falsos positivos nem substitui a validação de voz real no celular.
