const { readFileSync } = require('fs');
const { initializeTestEnvironment, assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');

const projectId = 'shigodeki-project-test-' + Date.now();

describe('🔐 Project Access Control Tests', () => {
  let testEnv;

  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: projectId,
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

  describe('📁 Project CRUD Operations', () => {

    it('✅ Should SUCCEED: User can create project with themselves as member', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();

      await assertSucceeds(
        aliceDb.collection('projects').doc('project-1').set({
          name: 'Test Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid'],
          isArchived: false,
          isCompleted: false
        })
      );
    });

    it('❌ Should FAIL: User cannot create project without including themselves in memberIds', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();

      await assertFails(
        aliceDb.collection('projects').doc('project-1').set({
          name: 'Sneaky Project',
          ownerId: 'bob-uid',
          memberIds: ['bob-uid'],
          isArchived: false,
          isCompleted: false
        })
      );
    });

    it('✅ Should SUCCEED: Member can read their project', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();

      // Set up project with Alice as member
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Team Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertSucceeds(
        aliceDb.collection('projects').doc('project-1').get()
      );
    });

    it('❌ Should FAIL: Non-member cannot read project', async () => {
      const charlieDb = testEnv.authenticatedContext('charlie-uid').firestore();

      // Set up project without Charlie
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Private Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertFails(
        charlieDb.collection('projects').doc('project-1').get()
      );
    });

    it('✅ Should SUCCEED: Member can update project', async () => {
      const bobDb = testEnv.authenticatedContext('bob-uid').firestore();

      // Set up project with Bob as member
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Team Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertSucceeds(
        bobDb.collection('projects').doc('project-1').update({
          name: 'Updated Project Name'
        })
      );
    });

    it('❌ Should FAIL: Non-member cannot update project', async () => {
      const charlieDb = testEnv.authenticatedContext('charlie-uid').firestore();

      // Set up project without Charlie
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Private Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertFails(
        charlieDb.collection('projects').doc('project-1').update({
          name: 'Hacked Name'
        })
      );
    });

    it('✅ Should SUCCEED: Owner can delete project', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();

      // Set up project with Alice as owner
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Alice Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertSucceeds(
        aliceDb.collection('projects').doc('project-1').delete()
      );
    });

    it('❌ Should FAIL: Non-owner member cannot delete project', async () => {
      const bobDb = testEnv.authenticatedContext('bob-uid').firestore();

      // Set up project with Alice as owner, Bob as member
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Alice Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertFails(
        bobDb.collection('projects').doc('project-1').delete()
      );
    });
  });

  describe('📋 Project Subcollections (phases, tasks)', () => {

    it('✅ Should SUCCEED: Member can create phase in their project', async () => {
      const aliceDb = testEnv.authenticatedContext('alice-uid').firestore();

      // Set up project
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Team Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid'],
          isArchived: false
        });
      });

      await assertSucceeds(
        aliceDb.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1').set({
            name: 'Phase 1',
            order: 0
          })
      );
    });

    it('❌ Should FAIL: Non-member cannot create phase in project', async () => {
      const charlieDb = testEnv.authenticatedContext('charlie-uid').firestore();

      // Set up project without Charlie
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('projects').doc('project-1').set({
          name: 'Private Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
      });

      await assertFails(
        charlieDb.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1').set({
            name: 'Hacked Phase',
            order: 0
          })
      );
    });

    it('✅ Should SUCCEED: Member can create task in their project phase', async () => {
      const bobDb = testEnv.authenticatedContext('bob-uid').firestore();

      // Set up project and phase
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('projects').doc('project-1').set({
          name: 'Team Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid', 'bob-uid'],
          isArchived: false
        });
        await db.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1').set({
            name: 'Phase 1',
            order: 0
          });
      });

      await assertSucceeds(
        bobDb.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1')
          .collection('tasks').doc('task-1').set({
            title: 'New Task',
            isCompleted: false
          })
      );
    });

    it('❌ Should FAIL: Non-member cannot read tasks in project', async () => {
      const charlieDb = testEnv.authenticatedContext('charlie-uid').firestore();

      // Set up project with task
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('projects').doc('project-1').set({
          name: 'Private Project',
          ownerId: 'alice-uid',
          memberIds: ['alice-uid'],
          isArchived: false
        });
        await db.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1')
          .collection('tasks').doc('task-1').set({
            title: 'Secret Task',
            isCompleted: false
          });
      });

      await assertFails(
        charlieDb.collection('projects').doc('project-1')
          .collection('phases').doc('phase-1')
          .collection('tasks').doc('task-1').get()
      );
    });
  });
});
