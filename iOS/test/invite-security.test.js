const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

describe('Invitation Security Rules', function() {
  let testEnv;

  before(async function() {
    testEnv = await initializeTestEnvironment({
      projectId: 'shigodeki-test',
      firestore: {
        rules: require('fs').readFileSync('./firestore.rules', 'utf8'),
      },
    });
  });

  after(async function() {
    await testEnv.cleanup();
  });

  beforeEach(async function() {
    await testEnv.clearFirestore();
  });

  it('Family member can create invitation code with createdBy field', async function() {
    // Setup: Create a family with the user as a member
    const familyId = 'family123';
    const userId = 'user1';
    
    await testEnv.withSecurityRulesDisabled(context => {
      return context.firestore()
        .collection('families').doc(familyId)
        .set({
          name: 'Test Family',
          members: [userId],
          createdAt: new Date()
        });
    });

    const db = testEnv.authenticatedContext(userId).firestore();
    
    const inviteData = {
      familyId: familyId,
      familyName: 'Test Family',
      normalizedCode: 'ABC123',
      createdBy: userId,
      isActive: true,
      createdAt: new Date(),
      expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000)
    };

    await assertSucceeds(
      db.collection('invites_by_norm').doc('ABC123').set(inviteData)
    );
  });

  it('Non-family member cannot create invitation code', async function() {
    const familyId = 'family123';
    const userId = 'user1';
    const nonMemberId = 'user2';
    
    // Setup family without nonMemberId
    await testEnv.withSecurityRulesDisabled(context => {
      return context.firestore()
        .collection('families').doc(familyId)
        .set({
          name: 'Test Family',
          members: [userId],
          createdAt: new Date()
        });
    });

    const db = testEnv.authenticatedContext(nonMemberId).firestore();
    
    const inviteData = {
      familyId: familyId,
      familyName: 'Test Family',
      normalizedCode: 'ABC123',
      createdBy: nonMemberId,
      isActive: true,
      createdAt: new Date()
    };

    await assertFails(
      db.collection('invites_by_norm').doc('ABC123').set(inviteData)
    );
  });

  it('Anyone can read individual invitation codes', async function() {
    const normalizedCode = 'ABC123';
    
    // Setup invitation code
    await testEnv.withSecurityRulesDisabled(context => {
      return context.firestore()
        .collection('invites_by_norm').doc(normalizedCode)
        .set({
          familyId: 'family123',
          familyName: 'Test Family',
          normalizedCode: normalizedCode,
          createdBy: 'user1',
          isActive: true
        });
    });

    const db = testEnv.authenticatedContext('anyuser').firestore();
    
    await assertSucceeds(
      db.collection('invites_by_norm').doc(normalizedCode).get()
    );
  });

  it('List queries on invites_by_norm are forbidden', async function() {
    const db = testEnv.authenticatedContext('user1').firestore();
    
    await assertFails(
      db.collection('invites_by_norm').where('familyId', '==', 'family123').get()
    );
  });

  it('Family members can access family-scoped invitations', async function() {
    const familyId = 'family123';
    const userId = 'user1';
    
    // Setup family and invitation
    await testEnv.withSecurityRulesDisabled(context => {
      const batch = context.firestore().batch();
      batch.set(context.firestore().collection('families').doc(familyId), {
        name: 'Test Family',
        members: [userId],
        createdAt: new Date()
      });
      batch.set(
        context.firestore()
          .collection('families').doc(familyId)
          .collection('invites').doc('ABC123'),
        {
          normalizedCode: 'ABC123',
          familyId: familyId,
          isActive: true
        }
      );
      return batch.commit();
    });

    const db = testEnv.authenticatedContext(userId).firestore();
    
    // Should be able to read family-scoped invitations
    await assertSucceeds(
      db.collection('families').doc(familyId)
        .collection('invites').doc('ABC123').get()
    );
    
    // Should be able to list family-scoped invitations
    await assertSucceeds(
      db.collection('families').doc(familyId)
        .collection('invites').get()
    );
  });
});