import { describe, expect, it } from "vitest";
import { keys, t } from "./index";

describe("locale interpolation", () => {
  it("interpolates workspace placeholders", () => {
    expect(t(keys.workspace.subtitle, { email: "person@example.com" })).toBe(
      "Signed in as person@example.com.",
    );
    expect(t(keys.workspace.tokenExpiry, { at: "10:30" })).toBe("Access token expires at: 10:30");
  });
});
