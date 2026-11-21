-- Settings.lua
-- Saved-variable loading and slash-argument parsing, kept free of UI code so it
-- can be tested outside the game.

local addonName, ns = ...

ns.Settings = {}

--------------------------------------------------------------------------------
-- Saved variables
--------------------------------------------------------------------------------

-- Merges known, correctly-typed keys from `saved` into ns.db; anything else
-- (unknown keys, wrong types, a hand-edited file) is dropped.
function ns.Settings.LoadSavedVariables(saved)
  if type(saved) == "table" then
    ns.Merge(ns.db, saved, ns.defaults)
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

  first = first:lower()

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
