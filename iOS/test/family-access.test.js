const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

const projectId = 'shigodeki-family-test-' + Date.now();

describe('🏠 Family Member Access Tests - GREEN Implementation', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId,
      firestore: {
        rules: readFileSync('firestore.rules', 'utf8'),
        host: '127.0.0.1',
        port: 8080,
      },
    });
  });

  after(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  afterEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  describe('✅ GREEN TESTS - Family Member Access Working', () => {

    it('✅ Family members can read each other basic info (with familyIds)', async () => {
      const aliceId = 'alice-uid';
      const bobId = 'bob-uid';
      const familyId = 'family-1';

      // Set up family and users with familyIds field
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc(familyId).set({
          name: 'Test Family',
          members: [aliceId, bobId],
          createdAt: new Date()
        });

        await db.collection('users').doc(aliceId).set({
          name: 'Alice',
          familyIds: [familyId]
        });

        await db.collection('users').doc(bobId).set({
          name: 'Bob',
          familyIds: [familyId]
        });
      });

      const aliceDb = testEnv.authenticatedContext(aliceId).firestore();

      // Alice should be able to read Bob's basic info
      await assertSucceeds(
        aliceDb.collection('users').doc(bobId).get()
      );

      // Alice should still be able to read her own data
      await assertSucceeds(
        aliceDb.collection('users').doc(aliceId).get()
      );

      console.log('✅ Family member cross-access working!');
    });

    it('❌ Non-family members still cannot access each other data', async () => {
      const aliceId = 'alice-uid-2';
      const charlieId = 'charlie-uid';
      const familyId = 'family-2';

      // Set up users where Charlie is NOT in Alice's family
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc(aliceId).set({
          name: 'Alice',
          familyIds: [familyId]
        });

        await db.collection('users').doc(charlieId).set({
          name: 'Charlie',
          familyIds: ['different-family']
        });
      });

      const aliceDb = testEnv.authenticatedContext(aliceId).firestore();

      // Alice should NOT be able to read Charlie's data
      await assertFails(
        aliceDb.collection('users').doc(charlieId).get()
      );

      console.log('✅ Non-family member access correctly blocked!');
    });

    it('❌ Users without familyIds field cannot be accessed by family members', async () => {
      const aliceId = 'alice-uid-3';
      const bobId = 'bob-uid-3';
      const familyId = 'family-3';

      // Set up Alice with familyIds but Bob without familyIds field
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc(aliceId).set({
          name: 'Alice',
          familyIds: [familyId]
        });

        // Bob has no familyIds field - legacy user data
        await db.collection('users').doc(bobId).set({
          name: 'Bob'
          // No familyIds field
        });
      });

      const aliceDb = testEnv.authenticatedContext(aliceId).firestore();

      // Alice should NOT be able to read Bob's data (no familyIds field)
      await assertFails(
        aliceDb.collection('users').doc(bobId).get()
      );

      console.log('✅ Users without familyIds field correctly protected!');
    });
  });

  describe('🧪 Testing Real-World Scenario', () => {

    it('🎯 Recreate Issue #44 scenario and verify fix', async () => {
      // Real IDs from console log
      const hiroshiId = 'kH49JAs83MQPNRFf9WZ8Xzofboe2';
      const deraId = 'xEMEqpAKdiUPAYjXwQI9BhnziXf1';
      const familyId = 'family-700';

      // Set up the exact scenario from console log
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('families').doc(familyId).set({
          name: '700?',
          members: [hiroshiId, deraId],
          createdAt: new Date()
        });

        await db.collection('users').doc(hiroshiId).set({
          name: 'Hiroshi Kodera',
          familyIds: [familyId]
        });

        await db.collection('users').doc(deraId).set({
          name: 'デラ',
          familyIds: [familyId]
        });
      });

      const hiroshiDb = testEnv.authenticatedContext(hiroshiId).firestore();

      // This should now succeed with our new rule
      await assertSucceeds(
        hiroshiDb.collection('users').doc(deraId).get()
      );

      console.log('🎉 Issue #44 FIXED! Family member loading now works!');
    });
  });
});