const PocketBase = require('pocketbase/cjs');

const pb = new PocketBase(process.env.POCKETBASE_URL || 'http://127.0.0.1:8090');

// Auto-authenticate as admin if credentials provided
async function authenticateAdmin() {
  try {
    if (process.env.POCKETBASE_ADMIN_EMAIL && process.env.POCKETBASE_ADMIN_PASSWORD) {
      try {
        // Coba login v0.23+ (_superusers)
        await pb.collection('_superusers').authWithPassword(
          process.env.POCKETBASE_ADMIN_EMAIL,
          process.env.POCKETBASE_ADMIN_PASSWORD
        );
        console.log('✅ PocketBase admin authenticated (v0.23+ superuser)');
      } catch (err) {
        // Fallback ke login v0.22 (admins)
        await pb.admins.authWithPassword(
          process.env.POCKETBASE_ADMIN_EMAIL,
          process.env.POCKETBASE_ADMIN_PASSWORD
        );
        console.log('✅ PocketBase admin authenticated (v0.22 admin)');
      }
    } else {
      console.log('⚠️  PocketBase admin credentials not provided, skipping authentication');
    }
  } catch (error) {
    console.error('❌ PocketBase admin authentication failed:', error.message);
    console.log('⚠️  Backend will continue without admin authentication');
    console.log('💡 Tip: Check POCKETBASE_ADMIN_EMAIL and POCKETBASE_ADMIN_PASSWORD in .env');
  }
}

authenticateAdmin();

module.exports = pb;
