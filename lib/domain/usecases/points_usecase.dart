class PointsUseCase {
  int calculate(String service) {
    if (service == 'corte') return 10;
    if (service == 'barba') return 5;
    if (service == 'tinte') return 25;
    return 0;
  }
}
