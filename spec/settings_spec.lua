-- spec/settings_spec.lua
-- Phase 3 (#24): Settings.lua -- saved-variable filtering and the slash
-- argument handlers extracted from Config.lua per #21's decision.

local bootstrap = dofile("spec/bootstrap.lua")

describe("Settings.lua", function()
  local ns

  before_each(function()
    ns = bootstrap.LoadAddon()
  end)

  describe("LoadSavedVariables", function()
    it("does nothing but stamp dbVersion when there is nothing saved", function()
      ns.Settings.LoadSavedVariables(nil)

      assert.same(ns.defaults.enabled, ns.db.enabled)
      assert.equals(ns.DB_VERSION, ns.db.dbVersion)
      assert.equals(ns.db, CoyFlightline_GlobalData)
    end)

    it("drops unknown keys and keeps known, correctly-typed ones", function()
      ns.Settings.LoadSavedVariables({
        enabled = false,
        color = "yellow",
        unknownKey = 123,
      })

      assert.is_false(ns.db.enabled)
      assert.equals("yellow", ns.db.color)
      assert.is_nil(ns.db.unknownKey)
    end)

    it("drops keys whose saved value type does not match the default", function()
      ns.Settings.LoadSavedVariables({
        thickness = "not a number",
      })

      assert.equals(ns.defaults.thickness, ns.db.thickness)
    end)

    it("deep-copies saved tables instead of aliasing them", function()
      local saved = { customColor = { r = 0.5, g = 0.5, b = 0.5 } }
      ns.Settings.LoadSavedVariables(saved)

      saved.customColor.r = 0.9

      assert.equals(0.5, ns.db.customColor.r)
    end)

    it("stamps the current dbVersion and republishes the shared table", function()
      ns.Settings.LoadSavedVariables({})

      assert.equals(ns.DB_VERSION, ns.db.dbVersion)
      assert.equals(ns.db, CoyFlightline_GlobalData)
    end)
  end)

  describe("HandleNumber", function()
    local function format(v) return tostring(v) end

    it("clamps below the minimum", function()
      ns.Settings.HandleNumber("thickness", "thickness", "0", 1, 6, format)
      assert.equals(1, ns.db.thickness)
    end)

    it("clamps above the maximum", function()
      ns.Settings.HandleNumber("thickness", "thickness", "10", 1, 6, format)
      assert.equals(6, ns.db.thickness)
    end)

    it("passes ordinary in-range values through unchanged", function()
      ns.Settings.HandleNumber("thickness", "thickness", "3.5", 1, 6, format)
      assert.equals(3.5, ns.db.thickness)
    end)

    it("leaves the setting untouched on non-numeric input", function()
      local before = ns.db.thickness
      ns.Settings.HandleNumber("thickness", "thickness", "abc", 1, 6, format)
      assert.equals(before, ns.db.thickness)
    end)
  end)

  describe("HandleColor", function()
    it("accepts a known colour name", function()
      ns.Settings.HandleColor("yellow")
      assert.equals("yellow", ns.db.color)
    end)

    it("accepts three numeric components and clamps each to 0-1", function()
      ns.Settings.HandleColor("2", "-1", "0.5")

      assert.equals("custom", ns.db.color)
      assert.same({ r = 1, g = 0, b = 0.5 }, ns.db.customColor)
    end)

    it("falls back without changing the colour when input is neither", function()
      local before = ns.db.color
      ns.Settings.HandleColor("not-a-colour")
      assert.equals(before, ns.db.color)
    end)

    it("leaves the colour untouched when called with no arguments", function()
      local before = ns.db.color
      ns.Settings.HandleColor(nil)
      assert.equals(before, ns.db.color)
    end)
  end)
end)
