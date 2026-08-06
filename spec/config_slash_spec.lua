-- spec/config_slash_spec.lua
-- Phase 3 (#24): slash dispatch itself, not just the argument handlers --
-- this is the one test that would have caught the /cfl reshuffle shipping
-- untested in 1.1.0. Routing is asserted against the print buffer from
-- spec/bootstrap.lua rather than the Settings API, which stays unmocked.

local bootstrap = dofile("spec/bootstrap.lua")

local function containsText(prints, needle)
  for _, line in ipairs(prints) do
    if line:find(needle, 1, true) then
      return true
    end
  end
  return false
end

describe("HandleSlash dispatch", function()
  local ns, prints, dispatch

  before_each(function()
    ns, prints, dispatch = bootstrap.LoadAddon()
  end)

  it("registers itself under SlashCmdList", function()
    assert.is_function(dispatch)
  end)

  it("prints status and help on a bare /cfl", function()
    dispatch("")

    assert.is_true(containsText(prints, "dev - enabled"))
    assert.is_true(containsText(prints, "commands:"))
  end)

  it("treats a nil input the same as a bare /cfl", function()
    dispatch(nil)

    assert.is_true(containsText(prints, "commands:"))
  end)

  it("reports the options panel unavailable when it was never built", function()
    -- ADDON_LOADED never fires under the bootstrap, so BuildPanel never runs
    -- and ns.settingsCategory stays nil -- exactly the pcall-failure fallback
    -- path Config.lua ships for a Settings API signature change.
    dispatch("options")

    assert.is_true(containsText(prints, "options panel is unavailable"))
  end)

  it("routes status on its own", function()
    dispatch("status")

    assert.is_true(containsText(prints, "dev - enabled"))
    assert.is_false(containsText(prints, "commands:"))
  end)

  it("toggles the master switch and reports the new state", function()
    dispatch("off")
    assert.is_false(ns.db.enabled)
    assert.is_true(containsText(prints, "disabled."))

    dispatch("on")
    assert.is_true(ns.db.enabled)
  end)

  it("falls back to help for an unknown command", function()
    dispatch("nonsense")

    assert.is_true(containsText(prints, "commands:"))
  end)

  it("restores defaults on reset", function()
    ns.db.enabled = false
    ns.db.thickness = 6

    dispatch("reset")

    assert.equals(ns.defaults.enabled, ns.db.enabled)
    assert.equals(ns.defaults.thickness, ns.db.thickness)
  end)
end)
