-- spec/core_spec.lua
-- Phase 2 (#23): the pure geometry in Core.lua, plus the version-label
-- derivation extracted alongside it.

local bootstrap = dofile("spec/bootstrap.lua")

describe("Core.lua", function()
  local ns

  before_each(function()
    ns = bootstrap.LoadAddon()
  end)

  describe("ClipRayToRect", function()
    -- 100x100 rect, origin at its centre unless a case says otherwise.

    it("clips to the east wall", function()
      local x, y = ns.ClipRayToRect(50, 50, 1, 0, 100, 100)
      assert.equals(100, x)
      assert.equals(50, y)
    end)

    it("clips to the west wall", function()
      local x, y = ns.ClipRayToRect(50, 50, -1, 0, 100, 100)
      assert.equals(0, x)
      assert.equals(50, y)
    end)

    it("clips to the south wall (positive Y, y-down space)", function()
      local x, y = ns.ClipRayToRect(50, 50, 0, 1, 100, 100)
      assert.equals(50, x)
      assert.equals(100, y)
    end)

    it("clips to the north wall (negative Y, y-down space)", function()
      local x, y = ns.ClipRayToRect(50, 50, 0, -1, 100, 100)
      assert.equals(50, x)
      assert.equals(0, y)
    end)

    it("returns the origin's own wall when it starts on an edge facing in", function()
      local x, y = ns.ClipRayToRect(0, 50, 1, 0, 100, 100)
      assert.equals(100, x)
      assert.equals(50, y)
    end)

    it("returns nil when the origin is on an edge facing off it (t <= 0)", function()
      local x, y = ns.ClipRayToRect(0, 50, -1, 0, 100, 100)
      assert.is_nil(x)
      assert.is_nil(y)
    end)

    it("returns nil for a zero vector (t == huge early-out)", function()
      local x, y = ns.ClipRayToRect(50, 50, 0, 0, 100, 100)
      assert.is_nil(x)
      assert.is_nil(y)
    end)
  end)

  describe("ClipRayToCircle", function()
    it("lands on the radius along the given direction", function()
      local x, y = ns.ClipRayToCircle(50, 50, 1, 0, 20)
      assert.equals(70, x)
      assert.equals(50, y)
    end)

    it("works for any unit direction, not just the axes", function()
      local x, y = ns.ClipRayToCircle(0, 0, 0, -1, 15)
      assert.equals(0, x)
      assert.equals(-15, y)
    end)
  end)

  describe("FacingToVector", function()
    -- Inherited from Coywolf's original; HANDOFF.md warns not to "fix" these
    -- signs. This pins the mapping so that warning is enforceable.
    local EPSILON = 1e-9

    local function assertVector(facing, expectedX, expectedY)
      local x, y = ns.FacingToVector(facing)
      assert.near(expectedX, x, EPSILON)
      assert.near(expectedY, y, EPSILON)
    end

    it("faces north at 0 radians", function()
      assertVector(0, 0, -1)
    end)

    it("faces west at pi/2 radians (counter-clockwise from north)", function()
      assertVector(math.pi / 2, -1, 0)
    end)

    it("faces south at pi radians", function()
      assertVector(math.pi, 0, 1)
    end)

    it("faces east at 3*pi/2 radians", function()
      assertVector(3 * math.pi / 2, 1, 0)
    end)
  end)

  describe("ScaledThickness", function()
    before_each(function()
      ns.db.thickness = 2
    end)

    it("returns the raw setting when there is no frame", function()
      assert.equals(2, ns.ScaledThickness(nil))
    end)

    it("returns the raw setting when the frame's scale is zero or negative", function()
      local frame = { GetEffectiveScale = function() return 0 end }
      assert.equals(2, ns.ScaledThickness(frame))

      frame.GetEffectiveScale = function() return -1 end
      assert.equals(2, ns.ScaledThickness(frame))
    end)

    it("returns the raw setting when the frame reports no scale at all", function()
      local frame = { GetEffectiveScale = function() return nil end }
      assert.equals(2, ns.ScaledThickness(frame))
    end)

    it("compensates for a frame scaled below UIParent's", function()
      _G.UIParent.GetEffectiveScale = function() return 1 end
      local frame = { GetEffectiveScale = function() return 0.5 end }
      assert.equals(4, ns.ScaledThickness(frame))
    end)

    it("is a no-op when the frame matches UIParent's scale", function()
      _G.UIParent.GetEffectiveScale = function() return 1 end
      local frame = { GetEffectiveScale = function() return 1 end }
      assert.equals(2, ns.ScaledThickness(frame))
    end)
  end)

  describe("DeepCopy", function()
    it("copies nested tables without aliasing the source", function()
      local source = { a = 1, b = { c = 2 } }
      local copy = ns.DeepCopy(source)

      copy.b.c = 99

      assert.equals(1, copy.a)
      assert.equals(99, copy.b.c)
      assert.equals(2, source.b.c)
    end)
  end)

  describe("DeriveVersionLabel", function()
    -- Extracted from the file-scope version derivation: pure, and it targets
    -- the vv1.0.1 bug fixed in 1.1.0 (the label re-prefixing a "v" the tag
    -- already carried).

    it("falls back to dev for an unsubstituted packager token", function()
      local version, label = ns.DeriveVersionLabel("@project-version@")
      assert.equals("dev", version)
      assert.equals("dev", label)
    end)

    it("falls back to dev for nil or empty input", function()
      local version, label = ns.DeriveVersionLabel(nil)
      assert.equals("dev", version)
      assert.equals("dev", label)

      version, label = ns.DeriveVersionLabel("")
      assert.equals("dev", version)
      assert.equals("dev", label)
    end)

    it("does not re-prefix a tag that already carries a v", function()
      local version, label = ns.DeriveVersionLabel("v1.0.1")
      assert.equals("v1.0.1", version)
      assert.equals("v1.0.1", label)
    end)

    it("prefixes a tag with no v", function()
      local version, label = ns.DeriveVersionLabel("1.0.1")
      assert.equals("1.0.1", version)
      assert.equals("v1.0.1", label)
    end)
  end)
end)
