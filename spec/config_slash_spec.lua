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

  it("opens the options panel on a bare /cfl (S2), not status and help", function()
    dispatch("")

    -- ADDON_LOADED never fires under the bootstrap, so BuildPanel never runs
    -- and ns.settingsCategory stays nil -- the same unavailable-panel path
    -- "options" hits below.
    assert.is_true(containsText(prints, "options panel is unavailable"))
    assert.is_false(containsText(prints, "commands:"))
  end)

  it("treats a nil input the same as a bare /cfl", function()
    dispatch(nil)

    assert.is_true(containsText(prints, "options panel is unavailable"))
  end)

  it("config and gui are silent aliases that also open the panel", function()
    -- prints accumulates for the life of the test (see bootstrap.lua), so
    -- both dispatches are checked against the same running log.
    dispatch("config")
    dispatch("gui")
    local count = 0
    for _, line in ipairs(prints) do
      if line:find("options panel is unavailable", 1, true) then
        count = count + 1
      end
    end
    assert.equals(2, count)
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

  it("names the bad word before falling back to help (S4)", function()
    dispatch("nonsense")

    assert.is_true(containsText(prints, "unknown command: nonsense"))
    assert.is_true(containsText(prints, "commands:"))
  end)

  it("restores defaults on reset", function()
    ns.db.enabled = false
    ns.db.thickness = 6

    dispatch("reset")

    assert.equals(ns.defaults.enabled, ns.db.enabled)
    assert.equals(ns.defaults.thickness, ns.db.thickness)
  end)

  it("bare debug toggles the current state and reports it (S8)", function()
    ns.db.debug = false

    dispatch("debug")
    assert.is_true(ns.db.debug)

    dispatch("debug")
    assert.is_false(ns.db.debug)
  end)

  it("debug on/off sets the state explicitly", function()
    dispatch("debug on")
    assert.is_true(ns.db.debug)

    dispatch("debug off")
    assert.is_false(ns.db.debug)
  end)

  it("rejects an invalid debug value instead of applying it (S12)", function()
    ns.db.debug = true

    dispatch("debug maybe")

    assert.is_true(ns.db.debug)
    assert.is_true(containsText(prints, "expected 'on' or 'off'"))
  end)

  it("minimap accepts an explicit on/off in addition to its bare toggle", function()
    ns.db.showMinimap = true

    dispatch("minimap off")
    assert.is_false(ns.db.showMinimap)

    dispatch("minimap on")
    assert.is_true(ns.db.showMinimap)

    dispatch("minimap")
    assert.is_false(ns.db.showMinimap)
  end)

  it("version prints the addon version", function()
    dispatch("version")

    assert.is_true(containsText(prints, ns.versionLabel))
  end)

  it("status reports the debug logging state", function()
    ns.db.debug = true

    dispatch("status")

    assert.is_true(containsText(prints, "debug logging: true"))
  end)
end)
