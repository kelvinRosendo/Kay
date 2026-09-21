enum KayState {
  idle('Em repouso'),
  listening('Ouvindo'),
  thinking('Processando'),
  speaking('Falando');

  const KayState(this.label);
  final String label;
}
