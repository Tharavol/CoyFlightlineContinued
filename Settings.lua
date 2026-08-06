-- Settings.lua
-- Saved-variable loading and slash-argument parsing. Pulled out of Config.lua
-- so this logic can be loaded and tested outside the game; Config.lua consumes
-- it for the options panel and slash commands.

local addonName, ns = ...

ns.Settings = {}

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

-- Copies known, correctly-typed keys from `saved` into ns.db. Unknown keys and
-- keys whose value type does not match the default are dropped -- this is the
-- one guard against a malformed table from a future migration or a hand-edited
-- SavedVariables file.
function ns.Settings.LoadSavedVariables(saved)
  if type(saved) == "table" then
    -- Copy into the existing ns.db rather than replacing it: the Settings API
    -- binds controls to this exact table reference. Unknown keys are dropped.
    for key, value in pairs(saved) do
      local default = ns.defaults[key]
      if default ~= nil and type(value) == type(default) then
        if type(value) == "table" then
          ns.db[key] = ns.DeepCopy(value)
        else
          ns.db[key] = value
        end
      end
    end
  end

  ns.db.dbVersion = ns.DB_VERSION
  CoyFlightline_GlobalData = ns.db
end

--------------------------------------------------------------------------------
-- Slash argument handling
--------------------------------------------------------------------------------

-- Parses either a known colour name or three 0-1 numeric components. Prints
-- usage/errors and returns nothing; callers read the result back off ns.db.
function ns.Settings.HandleColor(first, second, third)
  if not first then
    ns.Print("usage: /cfl color <name> or /cfl color <r> <g> <b>")
    return
  end

  if ns.COLORS[first] then
    ns.db.color = first
    ns.Refresh()
    ns.Print("colour set to " .. first .. ".")
    return
  end

  local r, g, b = tonumber(first), tonumber(second), tonumber(third)
  if r and g and b then
    ns.db.customColor = {
      r = math.max(0, math.min(1, r)),
      g = math.max(0, math.min(1, g)),
      b = math.max(0, math.min(1, b)),
    }
    ns.db.color = "custom"
    ns.Refresh()
    ns.Print(("colour set to %.2f, %.2f, %.2f."):format(
      ns.db.customColor.r, ns.db.customColor.g, ns.db.customColor.b))
    return
  end

  ns.Print("unknown colour. Try white, yellow, cyan, magenta, green, or three numbers 0-1.")
end

-- Clamps a slash-supplied numeric value into [minValue, maxValue] and stores it
-- under `key`. Prints usage on non-numeric input.
function ns.Settings.HandleNumber(key, label, value, minValue, maxValue, format)
  local number = tonumber(value)
  if not number then
    ns.Print(("usage: /cfl %s <%s-%s>"):format(key, minValue, maxValue))
    return
  end
  ns.db[key] = math.max(minValue, math.min(maxValue, number))
  ns.Refresh()
  ns.Print(("%s set to %s."):format(label, format(ns.db[key])))
end
