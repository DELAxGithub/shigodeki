const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

const projectId = 'shigodeki-test';

describe('🔥 Firebase Security Rules - Border Defense Tests', () => {
  let testEnv;

  before(async () => {
    // Initialize test environment with our firestore rules
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
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe('🚨 RED TESTS - Reproducing Current Permission Errors', () => {
    
    it('❌ Should FAIL: Unauthenticated user accessing projectInvitations', async () => {
      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      
      // This should fail - reproducing current error
      await assertFails(
        unauthedDb.collection('projectInvitations').doc('449324').get()
      );
    });

    it('❌ Should FAIL: User reading other users data for family member loading', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();
      
      // This should fail - user trying to read another user's data
      // This reproduces: "Listen for query at users/xEMEqpAKdiUPAYjXwQI9BhnziXf1 failed: Missing or insufficient permissions"
      await assertFails(
        aliceDb.collection('users').doc('bob-uid').get()
      );
    });

    it('❌ Should FAIL: User accessing projectInvitations without proper invitation context', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();
      
      // Current rule allows any authenticated user to read projectInvitations
      // But the real issue might be the invitation code format or context
      const invitationRead = aliceDb.collection('projectInvitations').doc('449324').get();
      
      // Let's see what the current rule actually does
      await assertSucceeds(invitationRead);
    });
  });

  describe('🎯 Expected Behavior Tests', () => {
    
    it('✅ Should SUCCEED: Authenticated user can read their own user data', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();
      
      // Set up user data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('users').doc('alice-uid').set({
          name: 'Alice',
          email: 'alice@example.com'
        });
      });
      
      await assertSucceeds(
        aliceDb.collection('users').doc('alice-uid').get()
      );
    });

    it('✅ Should SUCCEED: Family member accessing family data', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();
      
      // Set up family with Alice as member
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('families').doc('family-1').set({
          name: 'Test Family',
          members: ['alice-uid', 'bob-uid'],
          createdAt: new Date(),
          invitationCode: '449324'
        });
      });
      
      await assertSucceeds(
        aliceDb.collection('families').doc('family-1').get()
      );
    });
  });

  describe('🔍 Invitation System Analysis', () => {
    
    it('🧪 ANALYSIS: Current projectInvitations access pattern', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();
      const bobDb = testEnv.authenticatedContext('bob-uid').firestore();
      
      // Set up an invitation
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projectInvitations').doc('449324').set({
          familyId: 'family-1',
          createdBy: 'alice-uid',
          createdAt: new Date(),
          expiresAt: new Date(Date.now() + 86400000) // 24 hours
        });
      });
      
      // Current rule: "allow read, write, create: if request.auth != null;"
      // This means ANY authenticated user can read ANY invitation
      await assertSucceeds(
        aliceDb.collection('projectInvitations').doc('449324').get()
      );
      
      await assertSucceeds(
        bobDb.collection('projectInvitations').doc('449324').get()
      );
      
      console.log('🔍 Current rule allows any authenticated user to read any invitation');
    });
  });
});