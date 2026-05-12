/// <reference types="node" />
import { expect, test } from "@playwright/test";

const e2eEmail = process.env.KANDO_E2E_EMAIL ?? "";
const e2ePassword = process.env.KANDO_E2E_PASSWORD ?? "";

// @req AUTH-001
test.skip(!e2eEmail || !e2ePassword, "Set KANDO_E2E_EMAIL and KANDO_E2E_PASSWORD for real sign-in e2e.");

test("signs in against real backend without mocked endpoints", async ({ page }) => {
  await page.goto("/");

  await page.getByTestId("auth.email").fill(e2eEmail);
  await page.getByTestId("auth.password").fill(e2ePassword);
  await page.getByTestId("auth.signin.submit").click();

  await expect(page.getByText("Board workspace")).toBeVisible();
});
