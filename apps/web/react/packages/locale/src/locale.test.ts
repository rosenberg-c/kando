import { describe, expect, it } from "vitest";
import { keys, t } from "./index";

describe("locale interpolation", () => {
  it("interpolates settings identity placeholders", () => {
    expect(t(keys.app.settings.signedInAs, { email: "person@example.com" })).toBe(
      "Signed in as person@example.com",
    );
  });
});
