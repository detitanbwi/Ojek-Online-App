String formatPrice(String price) {
  final intVal = int.tryParse(price.replaceAll('.', ''));
  if (intVal == null) return price;
  final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  return intVal.toString().replaceAllMapped(reg, (Match m) => '${m[1]}.');
}
