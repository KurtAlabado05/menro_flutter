import test from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";

import {
  handleOrganizationAdminRequest,
  isOrganizationAdminRole,
  organizationPermitFingerprints,
} from "../src/organizationAdmin.js";

const env = { ADMIN_ORIGINS: "http://localhost:3000" };

test("organization reviewer role check accepts admin aliases used by the web app", () => {
  for (const role of ["admin", "super_admin", "system_admin", "administrator", "sysadmin", "Super Admin"]) {
    assert.equal(isOrganizationAdminRole(role), true, role);
  }
  assert.equal(isOrganizationAdminRole("receiving_clerk"), false);
  assert.equal(isOrganizationAdminRole("organization"), false);
});

test("permit fingerprints match the Firebase organization registry format", async () => {
  const secret = "shared-test-secret";
  const actual = await organizationPermitFingerprints({
    issuer: "City Hall",
    jurisdiction: "Baliwag, Bulacan",
    number: "BP-001 / 2026",
  }, secret);
  const exactIdentity = JSON.stringify(["city hall", "baliwag bulacan", "bp0012026"]);
  const legacyIdentity = JSON.stringify(["baliwag bulacan", "bp0012026"]);

  assert.equal(actual.exact, createHmac("sha256", secret).update(exactIdentity).digest("hex"));
  assert.equal(actual.legacy, createHmac("sha256", secret).update(legacyIdentity).digest("hex"));
});

test("permit fingerprints fail closed when the shared registry secret is missing", async () => {
  await assert.rejects(
    organizationPermitFingerprints({ issuer: "City Hall", jurisdiction: "Baliwag, Bulacan", number: "BP-001" }, ""),
    (error) => error.status === 503 && error.code === "failed-precondition",
  );
});

test("organization API allows preflight from configured admin origin", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/list", {
      method: "OPTIONS",
      headers: { Origin: "http://localhost:3000" },
    }),
    env,
  );

  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "http://localhost:3000");
});

test("organization API rejects unconfigured origins", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/list", {
      method: "POST",
      headers: { Origin: "https://untrusted.example" },
      body: "{}",
    }),
    env,
  );

  assert.equal(response.status, 403);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
});

test("organization API requires a Firebase bearer token", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/list", {
      method: "POST",
      headers: {
        Origin: "http://localhost:3000",
        "Content-Type": "application/json",
      },
      body: "{}",
    }),
    env,
  );
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.error.code, "unauthenticated");
});

test("applicant submission also requires a Firebase bearer token", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/submit-application", {
      method: "POST",
      headers: {
        Origin: "http://localhost:3000",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ legalName: "Example Cooperative" }),
    }),
    env,
  );
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.error.code, "unauthenticated");
});

test("permit replacement requires a Firebase bearer token", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/update-permit", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        organizationId: "org-1",
        permitDocumentUrl: "https://res.cloudinary.com/dfo5l4d4t/raw/upload/permit.pdf",
      }),
    }),
    env,
  );
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.error.code, "unauthenticated");
});

test("native applicant requests without Origin still require Firebase authentication", async () => {
  const response = await handleOrganizationAdminRequest(
    new Request("https://worker.example/organization-admin/submit-application", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ legalName: "Example Cooperative" }),
    }),
    env,
  );
  const payload = await response.json();

  assert.equal(response.status, 401);
  assert.equal(payload.error.code, "unauthenticated");
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), null);
});
