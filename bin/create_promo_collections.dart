import 'package:pocketbase/pocketbase.dart';

void main() async {
  final pb = PocketBase('http://127.0.0.1:8090');

  try {
    print('Menghubungkan ke PocketBase...');
    // 1. Authenticate as Admin
    await pb.admins.authWithPassword('kartara@gmail.com', 'kartara123');
    print('✅ Berhasil masuk sebagai Admin PocketBase!\n');

    // 2. Create Banners Collection
    try {
      print('Membuat koleksi "banners"...');
      await pb.collections.create(body: {
        'name': 'banners',
        'type': 'base',
        'schema': [
          {
            'name': 'title',
            'type': 'text',
            'required': true,
          },
          {
            'name': 'subtitle',
            'type': 'text',
            'required': false,
          },
          {
            'name': 'image',
            'type': 'file',
            'required': false,
            'options': {
              'maxSelect': 1,
              'maxSize': 5242880,
            }
          },
          {
            'name': 'isActive',
            'type': 'bool',
            'required': false,
          }
        ],
        'listRule': '',
        'viewRule': '',
        'createRule': 'id != ""', // allow admins/users
        'updateRule': 'id != ""',
        'deleteRule': 'id != ""',
      });
      print('✅ Koleksi "banners" berhasil dibuat!');
      
      // Seed Banners
      print('Memasukkan banner promo awal...');
      await pb.collection('banners').create(body: {
        'title': 'Diskon 20%',
        'subtitle': 'Spesial Krupuk Tengiri Asli!',
        'image': 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?auto=format&fit=crop&w=800&q=80',
        'isActive': true,
      });
      await pb.collection('banners').create(body: {
        'title': 'Krupuk Udang Gurih',
        'subtitle': 'Bahan Udang Segar Pilihan Jepara!',
        'image': 'https://images.unsplash.com/photo-1555126634-323283e090fa?auto=format&fit=crop&w=800&q=80',
        'isActive': true,
      });
      print('✅ Banner awal berhasil dimasukkan!\n');
    } catch (e) {
      print('ℹ️ Koleksi "banners" sudah ada atau dilewati: $e\n');
    }

    // 3. Create Coupons Collection
    try {
      print('Membuat koleksi "coupons"...');
      await pb.collections.create(body: {
        'name': 'coupons',
        'type': 'base',
        'schema': [
          {
            'name': 'code',
            'type': 'text',
            'required': true,
          },
          {
            'name': 'discountAmount',
            'type': 'number',
            'required': true,
          },
          {
            'name': 'minPurchase',
            'type': 'number',
            'required': false,
          },
          {
            'name': 'isActive',
            'type': 'bool',
            'required': false,
          }
        ],
        'listRule': '',
        'viewRule': '',
        'createRule': 'id != ""',
        'updateRule': 'id != ""',
        'deleteRule': 'id != ""',
      });
      print('✅ Koleksi "coupons" berhasil dibuat!');

      // Seed Coupons
      print('Memasukkan kupon promo awal...');
      await pb.collection('coupons').create(body: {
        'code': 'KARTARACERIA',
        'discountAmount': 10000,
        'minPurchase': 50000,
        'isActive': true,
      });
      await pb.collection('coupons').create(body: {
        'code': 'DISKON20K',
        'discountAmount': 20000,
        'minPurchase': 100000,
        'isActive': true,
      });
      print('✅ Kupon awal berhasil dimasukkan!\n');
    } catch (e) {
      print('ℹ️ Koleksi "coupons" sudah ada atau dilewati: $e\n');
    }

    print('🎉 Selamat! Koleksi Banners & Coupons telah terhubung nyata ke PocketBase!');
  } catch (e) {
    print('❌ Gagal menjalankan inisialisasi: $e');
  }
}
