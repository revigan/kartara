import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');
  
  try {
    print('Menghubungkan ke PocketBase di http://127.0.0.1:8090...');
    final records = await pb.collection('users').getFullList();
    print('\n=== DAFTAR USER DI POCKETBASE ===');
    if (records.isEmpty) {
      print('Database kosong. Tidak ada user yang terdaftar.');
    } else {
      for (var record in records) {
        print('- ID: ${record.id} | Data: ${record.data}');
      }
    }
    print('================================\n');
  } catch (e) {
    print('Gagal mengambil data user: $e');
  }
}
