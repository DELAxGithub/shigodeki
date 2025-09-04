const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

const projectId = 'shigodeki-test';

describe('🎯 Realistic Security Tests - Based on Console Log Errors', () => {
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
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  describe('🚨 Reproducing Actual Console Log Errors', () => {
    
    it('❌ Real Error: "Listen for query at projectInvitations/449324 failed"', async () => {
      // This is the actual error from console log
      // Let's see if we can reproduce it with specific conditions
      
      const userDb = testEnv.authenticatedContext('kH49JAs83MQPNRFf9WZ8Xzofboe2').firestore();
      
      // Try to listen to the exact document that failed
      const invitationRef = userDb.collection('projectInvitations').doc('449324');
      
      // Current rule should allow this, but let's see what happens
      await assertSucceeds(invitationRef.get());
      
      console.log('🔍 Current rule allows access to projectInvitations/449324');
    });

    it('❌ Real Error: "Listen for query at users/{userId} failed"', async () => {
      // From console: "Listen for query at users/xEMEqpAKdiUPAYjXwQI9BhnziXf1 failed"
      
      const currentUserDb = testEnv.authenticatedContext('kH49JAs83MQPNRFf9WZ8Xzofboe2').firestore();
      const targetUserId = 'xEMEqpAKdiUPAYjXwQI9BhnziXf1';
      
      // This should fail - user trying to read another user's data
      await assertFails(
        currentUserDb.collection('users').doc(targetUserId).get()
      );
      
      console.log('✅ Correctly blocks cross-user data access');
    });
    
    it('🧪 Testing Family Member Loading Pattern', async () => {
      // From console: "[Issue #44] Loading 2 family members"
      // This might be the real issue - loading family member data requires cross-user access
      
      const aliceId = 'kH49JAs83MQPNRFf9WZ8Xzofboe2';
      const bobId = 'xEMEqpAKdiUPAYjXwQI9BhnziXf1';
      
      const aliceDb = testEnv.authenticatedContext(aliceId).firestore();
      
      // Set up family with both users as members
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('families').doc('family-700').set({
          name: '700?',
          members: [aliceId, bobId],
          createdAt: new Date()
        });
        
        // Set up user data
        await context.firestore().collection('users').doc(aliceId).set({
          name: 'Hiroshi Kodera'
        });
        
        await context.firestore().collection('users').doc(bobId).set({
          name: 'デラ'
        });
      });
      
      // Alice tries to load family data - should work
      await assertSucceeds(
        aliceDb.collection('families').doc('family-700').get()
      );
      
      // Alice tries to load Bob's user data for family member display - this fails with current rules
      await assertFails(
        aliceDb.collection('users').doc(bobId).get()
      );
      
      console.log('🚨 Found the issue! Family member loading requires cross-user access');
    });

    it('🔧 Potential Solution: Family-based user data access', async () => {
      // Test if we need a new rule for family members to read each other's basic info
      
      const aliceId = 'alice-uid';
      const bobId = 'bob-uid';
      
      const aliceDb = testEnv.authenticatedContext(aliceId).firestore();
      
      // Set up family and user data
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('families').doc('test-family').set({
          name: 'Test Family',
          members: [aliceId, bobId]
        });
        
        await context.firestore().collection('users').doc(bobId).set({
          name: 'Bob',
          familyIds: ['test-family']
        });
      });
      
      // With current rules, this fails
      await assertFails(
        aliceDb.collection('users').doc(bobId).get()
      );
      
      console.log('💡 We need a new rule: family members should be able to read basic info of other family members');
    });
  });

  describe('🎯 Required Rule Improvements', () => {
    
    it('📋 Rule needed: Family members can read each other basic user info', () => {
      console.log('📝 REQUIRED: Add rule to allow family members to read each other\'s basic user data');
      console.log('📝 REQUIRED: This would fix the "[Issue #44] Error loading user" problem');
    });
    
    it('📋 Rule needed: More restrictive projectInvitations access', () => {
      console.log('📝 OPTIONAL: Make projectInvitations more restrictive than "any authenticated user"');
      console.log('📝 OPTIONAL: Only allow access to invitations you created or were invited to');
    });
  });
});