/*
Node.js script to seed MENRO community events into Firestore.

Usage:
  1) Install dependencies:
     npm init -y
     npm install firebase-admin

  2) Set credentials (one of these):
     - Set environment variable:
         set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\serviceAccount.json
       (Windows PowerShell: $env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\path\to\serviceAccount.json')
     - Or pass the service account JSON path with --serviceAccount, or as the first positional argument.
     - Also ensure your project ID is available via --projectId or GCLOUD_PROJECT / GOOGLE_CLOUD_PROJECT / FIREBASE_PROJECT.

  3) Run:
     node tools/seed_menro_events.js --serviceAccount C:\path\to\serviceAccount.json --projectId your-project-id
     node tools/seed_menro_events.js C:\path\to\serviceAccount.json --projectId your-project-id

Optional flags:
     node tools/seed_menro_events.js --serviceAccount C:\path\to\serviceAccount.json --projectId your-firebase-project-id
     node tools/seed_menro_events.js --verify

The script writes documents under the `projects` collection using the app schema and prints seeded document IDs.
*/

const admin = require('firebase-admin');
const path = require('path');

function getArgValue(names) {
  for (const name of names) {
    const idx = process.argv.indexOf(name);
    if (idx !== -1 && idx + 1 < process.argv.length) {
      return process.argv[idx + 1];
    }
  }
  return null;
}

function hasArg(name) {
  return process.argv.includes(name);
}

function getPositionalServiceAccount() {
  const args = process.argv.slice(2);
  for (const arg of args) {
    if (!arg.startsWith('-')) {
      return arg;
    }
  }
  return null;
}

function resolveServiceAccount() {
  const svcPath = getArgValue(['--serviceAccount', '-s']) || process.env.GOOGLE_APPLICATION_CREDENTIALS || getPositionalServiceAccount();
  if (!svcPath) {
    return null;
  }

  try {
    return require(path.resolve(svcPath));
  } catch (err) {
    console.error(`Unable to load service account JSON from ${svcPath}.`);
    console.error(err);
    process.exit(1);
  }
}

function initFirebase() {
  const serviceAccount = resolveServiceAccount();
  let projectId = getArgValue(['--projectId', '-p']) || process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT || process.env.FIREBASE_PROJECT;
  let appConfig = {};

  if (serviceAccount) {
    appConfig.credential = admin.credential.cert(serviceAccount);
    if (!projectId && serviceAccount.project_id) {
      projectId = serviceAccount.project_id;
    }
  } else {
    appConfig.credential = admin.credential.applicationDefault();
  }

  if (projectId) {
    appConfig.projectId = projectId;
  }

  if (!appConfig.projectId) {
    console.error('No Firebase project ID found.');
    console.error('Pass --projectId, set GCLOUD_PROJECT/GOOGLE_CLOUD_PROJECT/FIREBASE_PROJECT, or use a service account JSON with project_id.');
    process.exit(1);
  }

  try {
    admin.initializeApp(appConfig);
  } catch (err) {
    console.error('Failed to initialize Firebase Admin. Provide a valid service account JSON with --serviceAccount or set GOOGLE_APPLICATION_CREDENTIALS, and optionally pass --projectId.');
    console.error(err);
    process.exit(1);
  }
}

async function seed() {
  initFirebase();
  const db = admin.firestore();

  const now = new Date();

  const events = [
    {
      title: 'Weekly Clean-up Drives',
      description: 'A barangay-wide initiative to clear public roads, waterways, and open spaces of litter every Saturday.',
      location: 'Various barangay sites, Bulacan',
      status: 'ongoing',
      category: 'Clean-up Drive',
      progress: 0.5,
      currentProgress: 12,
      targetProgress: 24,
      progressUnit: 'sessions completed',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 30 * 24 * 3600 * 1000)),
      participantCount: 143,
      participants: [],
      updates: [
        {
          id: 'u_cleanup_1',
          content: 'This week’s clean-up collected 280 kg of recyclables from the riverbank.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 24 * 3600 * 1000)),
        },
      ],
    },
    {
      title: 'Tree Planting Initiatives',
      description: 'Planting native and fruit-bearing trees across barangays to restore green cover and support climate resilience.',
      location: 'Nangka, San Jose del Monte, Bulacan',
      status: 'ongoing',
      category: 'Tree Planting',
      progress: 0.35,
      currentProgress: 700,
      targetProgress: 2000,
      progressUnit: 'saplings planted',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 45 * 24 * 3600 * 1000)),
      participantCount: 78,
      participants: [],
      updates: [
        {
          id: 'u_tree_1',
          content: 'Planted 120 trees in the barangay park during today’s tree planting drive.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 10 * 3600 * 1000)),
        },
      ],
    },
    {
      title: 'Palit-Basura Program',
      description: 'Community recycling swap program where residents exchange sorted waste for eco-friendly goods and seedlings.',
      location: 'Municipal Plaza, Baliwag, Bulacan',
      status: 'pending',
      category: 'Recycling',
      progress: 0.0,
      currentProgress: 0,
      targetProgress: 10,
      progressUnit: 'exchange days',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 60 * 24 * 3600 * 1000)),
      participantCount: 0,
      participants: [],
      updates: [],
    },
    {
      title: 'Eco-Bricks Program',
      description: 'Collecting and repurposing plastic waste into eco-bricks for community construction projects.',
      location: 'Barangay Hagonoy, Bulacan',
      status: 'ongoing',
      category: 'Eco-Bricks',
      progress: 0.55,
      currentProgress: 55,
      targetProgress: 100,
      progressUnit: 'eco-bricks produced',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 20 * 24 * 3600 * 1000)),
      participantCount: 60,
      participants: [],
      updates: [
        {
          id: 'u_ecobrick_1',
          content: 'Local volunteers produced 30 eco-bricks in today’s workshop.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 3 * 24 * 3600 * 1000)),
        },
      ],
    },
    {
      title: 'Lakbay Aral / Climate Center Tours',
      description: 'Guided educational tours of the Climate Center to raise awareness of local environmental resilience projects.',
      location: 'Climate Center, Bulacan',
      status: 'ongoing',
      category: 'Education',
      progress: 0.25,
      currentProgress: 5,
      targetProgress: 20,
      progressUnit: 'tours held',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 40 * 24 * 3600 * 1000)),
      participantCount: 95,
      participants: [],
      updates: [
        {
          id: 'u_tour_1',
          content: 'The latest tour hosted 22 students from a nearby school.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 24 * 3600 * 1000)),
        },
      ],
    },
    {
      title: 'Environmental Awareness Seminars',
      description: 'A series of seminars on waste segregation, climate resilience, and sustainable living for barangay residents.',
      location: 'Baliwag Multi-Purpose Hall',
      status: 'pending',
      category: 'Awareness',
      progress: 0.0,
      currentProgress: 0,
      targetProgress: 6,
      progressUnit: 'seminars scheduled',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 35 * 24 * 3600 * 1000)),
      participantCount: 0,
      participants: [],
      updates: [],
    },
    {
      title: 'Upscaling Workshops (Tarpaulin to Bags)',
      description: 'Hands-on workshops teaching residents how to convert tarpaulin waste into reusable bags and pouches.',
      location: 'Barangay Hall, San Jose del Monte, Bulacan',
      status: 'pending',
      category: 'Upcycling',
      progress: 0.0,
      currentProgress: 0,
      targetProgress: 5,
      progressUnit: 'workshops planned',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 50 * 24 * 3600 * 1000)),
      participantCount: 0,
      participants: [],
      updates: [],
    },
    {
      title: 'Eco-Takbo (Environmental Fun Run)',
      description: 'A fun run to promote physical fitness and environmental awareness while collecting litter along the route.',
      location: 'NLEX Skyway Ramp, Bulacan',
      status: 'ongoing',
      category: 'Sports',
      progress: 0.6,
      currentProgress: 3,
      targetProgress: 5,
      progressUnit: 'runs organized',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 18 * 24 * 3600 * 1000)),
      participantCount: 320,
      participants: [],
      updates: [
        {
          id: 'u_run_1',
          content: 'The latest run brought together 120 runners and collected plastics along the course.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 2 * 24 * 3600 * 1000)),
        },
      ],
    },
    {
      title: 'Garbage to Garden',
      description: 'A support program for composting and urban gardening to turn organic waste into healthy community gardens.',
      location: 'Barangay Sugod, San Jose del Monte, Bulacan',
      status: 'ongoing',
      category: 'Urban Gardening',
      progress: 0.45,
      currentProgress: 9,
      targetProgress: 20,
      progressUnit: 'garden plots created',
      createdBy: 'menro',
      createdByName: 'MENRO Baliwag',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      targetCompletionDate: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 28 * 24 * 3600 * 1000)),
      participantCount: 64,
      participants: [],
      updates: [
        {
          id: 'u_garden_1',
          content: 'Completed three new compost beds and planted vegetable seedlings in the community garden.',
          authorName: 'MENRO Baliwag',
          postedAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() - 5 * 24 * 3600 * 1000)),
        },
      ],
    },
  ];

  console.log(`Seeding ${events.length} MENRO events into Firestore (collection: projects)`);

  const seededIds = [];

  for (const ev of events) {
    try {
      const normalizedId = ev.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '_')
        .replace(/^_|_$/g, '');
      const docId = ev.docId || `p_${normalizedId}`;
      const docRef = db.collection('projects').doc(docId);
      const payload = Object.assign({}, ev);
      delete payload.docId;
      payload.createdAt = admin.firestore.FieldValue.serverTimestamp();
      payload.coverImageUrl = payload.coverImageUrl || null;
      payload.galleryImages = payload.galleryImages || [];

      if (Array.isArray(payload.updates)) {
        payload.updates = payload.updates.map(u => ({
          id: u.id,
          content: u.content,
          authorName: u.authorName,
          postedAt: u.postedAt || admin.firestore.FieldValue.serverTimestamp(),
          imageUrl: u.imageUrl || null,
        }));
      }

      await docRef.set(payload);
      seededIds.push(docId);
      console.log(`Wrote project ${docId} • ${payload.title}`);
    } catch (err) {
      console.error('Failed to write project', ev.title, err);
    }
  }

  if (process.argv.includes('--verify')) {
    console.log('\nVerifying seeded documents...');
    for (const docId of seededIds) {
      const snapshot = await db.collection('projects').doc(docId).get();
      if (!snapshot.exists) {
        console.error(`Missing seeded project ${docId}`);
        continue;
      }
      const data = snapshot.data();
      console.log(`Verified ${docId}: ${data.title} | status=${data.status} | participants=${data.participantCount}`);
    }
  }

  console.log('Seeding complete.');
  process.exit(0);
}

seed().catch(err => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
