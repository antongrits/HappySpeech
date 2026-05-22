'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const {
  isValidEmail,
  isAllowedRole,
  buildInviteUrl,
  generateInviteId,
} = require('../lib/familyInvite');

test('isValidEmail accepts simple emails', () => {
  assert.ok(isValidEmail('user@example.com'));
  assert.ok(isValidEmail('a.b+tag@sub.example.co.uk'));
});

test('isValidEmail rejects garbage', () => {
  assert.equal(isValidEmail(''), false);
  assert.equal(isValidEmail('no-at-sign'), false);
  assert.equal(isValidEmail('a@b'), false);
  assert.equal(isValidEmail(123), false);
  assert.equal(isValidEmail(null), false);
  assert.equal(isValidEmail(undefined), false);
});

test('isAllowedRole only accepts parent | specialist', () => {
  assert.ok(isAllowedRole('parent'));
  assert.ok(isAllowedRole('specialist'));
  assert.equal(isAllowedRole('admin'), false);
  assert.equal(isAllowedRole(''), false);
  assert.equal(isAllowedRole(null), false);
});

test('buildInviteUrl uses canonical happyspeech.page.link host', () => {
  const url = buildInviteUrl('abc123');
  assert.equal(url, 'https://happyspeech.page.link/invite?token=abc123');
});

test('generateInviteId returns 32-char hex string', () => {
  const id = generateInviteId();
  assert.equal(id.length, 32);
  assert.match(id, /^[0-9a-f]{32}$/);
});

test('generateInviteId returns unique ids', () => {
  const a = generateInviteId();
  const b = generateInviteId();
  assert.notEqual(a, b);
});
