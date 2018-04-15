local Entity = require "entity"

local Monster = class.class(
  Entity, {
    methods = {
      Char = function(self)
        return "%"
      end,

      Color = function(self)
        return termfx.color.RED
      end,

      Collide = function(self, e)
        self.game:Log("A monster hits you for 2 damage.")
        e:SetHealth(e:Health() - 2)
      end,

      Die = function(self, e)
        self.game:Log("The monster dies.")
      end,

      Think = function(self)
        -- Your code here.
        function table_length(t)
          local count = 0
	        for _ in pairs(t) do
		        count = count + 1
	        end
          return count
        end
        if self:CanSee(self.game:Hero()) then
          local path = self:PathTo(self.game:Hero())
          self.game:TryMove(self, path[table_length(path)-1] - self:Pos())
      
        end
      end
    }
})

return Monster
