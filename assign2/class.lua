local Object
Object = {
  isinstance = function(cls) return cls == Object end,
  constructor = function() end,
  methods = {},
  data = {},
  metamethods = {}
}

-- This is a utility function you will find useful during the metamethods section.
function table.merge(src, dst)
  for k,v in pairs(src) do
    if not dst[k] then dst[k] = v end
  end
end

local function class(parent, child)

  -- The "child.methods or {}" syntax can be read as:
  -- "if child.methods is nil then this expression is {}, otherwise it is child.methods"
  -- Generally, "a or b" reduces to b if a is nil or false, evaluating to a otherwise.
  local methods = child.methods or {}
  local data = child.data or {}
  local constructor = child.constructor or parent.constructor
  local metamethods = child.metamethods or {}

  local Class = {}

  -- Your code here.
  -- Class.data = parent.data
  Class.data = {}
  table.merge(data, Class.data)
  table.merge(parent.data, Class.data)
  Class.methods = {}
  table.merge(methods, Class.methods)
  table.merge(parent.methods, Class.methods)
  Class.metamethods = {}
  table.merge(metamethods, Class.metamethods)
  table.merge(parent.metamethods, Class.metamethods)
  Class.constructor = constructor
  Class.isinstance = function(cls) 
    return cls == Class or parent.isinstance(cls)
  end

  function Class.new(...)
    local public_inst = {}
    local private_inst = {}

    public_inst.isinstance = function(self, cls)
      return Class.isinstance(cls)
    end
    private_inst.isinstance = public_inst.isinstance

    table.merge(Class.data, private_inst)

    for k, v in pairs(Class.methods) do
      public_inst[k] = function(self, ...)
        return v(private_inst, ...)
      end
      private_inst[k] = v
    end

    setmetatable(public_inst, Class.metamethods)
  
    constructor(private_inst, ...)
    return public_inst
  end

  return Class
end

return {class = class, Object = Object} 
