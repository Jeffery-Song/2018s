1. 遇到的问题

   * 最开始不考虑继承

     ```lua
     Class.constructor = constructor
     function Class.new(...)
       local public_inst = {}
       local private_inst = {}

       for k, v in pairs(methods) do
         public_inst[k] = function(self, ...)
           return v(private_inst, ...)
         end
       end

       for k, v in pairs(data) do
         private_inst[k] = v
       end
       setmetatable(private_inst, {__index = public_inst})

       constructor(private_inst, ...)

       for k, v in pairs(metamethods) do
         setmetatable(
           public_inst, 
           {[k] = function(self, ...) 
             return v(private_inst, ...) end}
         )
       end
     ```
     加入继承后，尝试直接让public_instmetatable置为parent，发现不允许在  metatable中使用其内的metatabel，故parent中必须有显示的存有methods与   data，故需要将data、methods放入新建的类中，而不是作为function class  中的local变量

   * 曾出现玩家血量降为0后游戏不退出，移动几次后变为操控monster的问题。

     因为debug时版本没有管理好，常用ctrl+z，使得一开始漏的Class.metamethod只有child的metamethod这一细节问题，在经过改正后，被撤销了，浪费了很多时间

   * 在WSL中roguelike与solution无法正常启动。

     换用带有图形界面的ubuntu系统解决

2. 实现Private data的方法

   将数据存在new中的一个local table中，返回的是一个只有methods的instance，实现方法为设置其__index或创建key为函数名，调用时替换第一个参数为local的data table的函数成员