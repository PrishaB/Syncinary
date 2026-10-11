'use strict';

/**
 * Lazy firebase-admin wrapper. Nothing initializes at require time, so a
 * missing service account never breaks startup, /flights, or tests; it only
 * fails the first /recommendations call (which maps it to 503).
 * Credentials come from ADC (`GOOGLE_APPLICATION_CREDENTIALS` locally).
 */

let adminApp;

function getApp() {
  if (!adminApp) {
    const { initializeApp } = require('firebase-admin/app');
    const projectId = process.env.FIREBASE_PROJECT_ID || process.env.GOOGLE_CLOUD_PROJECT;
    adminApp = initializeApp(projectId ? { projectId } : undefined);
  }
  return adminApp;
}

function getFirestore() {
  return require('firebase-admin/firestore').getFirestore(getApp());
}

/**
 * @param {string|undefined} header - the raw `Authorization` header.
 * @returns {Promise<{uid: string}>} rejects if the token is absent or invalid.
 */
async function verifyIdTokenFromHeader(header) {
  const match = typeof header === 'string' ? /^Bearer\s+(\S+)$/i.exec(header) : null;
  if (!match) throw new Error('missing bearer token');
  const decoded = await require('firebase-admin/auth').getAuth(getApp()).verifyIdToken(match[1]);
  return { uid: decoded.uid };
}

module.exports = { getFirestore, verifyIdTokenFromHeader };
