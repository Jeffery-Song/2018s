# PA1 RPC

PB15000301 宋小牛

1. **结合对 [`lua.lua`](../code/lua.lua) 和 [`lua-repl.lua`](../code/lua-repl.lua) 的理解和运行，回答问题**

   * **在 REPL 环境下运行 [`lua.lua`](../code/lua.lua) 会面临哪些问题？**

     *Answer:*

     1. 当将lua.lua作为脚本执行时，下面这段代码结果为`1 1`，而在repl中结果为`2 2`

        ```lua
        -- Variable is visible here
        local x = 1
        print(x)
        -- And not visible on the next call
        print(x)
        ```
        原因为repl为交互模式，其中每一个`>`的内容为一个block，上述代码中第一个`print(x)`与`local x`已不在同一个代码块中
        同样的，在line.102，`print(z)`的结果在repl中为nil

     2. 在line.131，`local ctr`使下一行`print(ctr())`找不到ctr变量。改`ctr`为全局变量后解决问题

     类似的，单独的local变量在其后的引用均会出错

   * **[`lua.lua`](../code/lua.lua) 中使用了哪些你不熟悉的语言特性（列举 2 个），结合代码及其执行说明你的理解。**

     *Answer:*

     1. metatable，对index进行定制

        变量t的所有取索引(`t.a`、`t[1]`)均由`__index`来完成，使用metatable可对其进行定制

        ```lua
        local t = {}
        function __index(t, k) -- t为被取索引的对象，k为使用的索引
           print('__index', t, k)
           return 0 -- 返回值为t.k or t[k]的返回值
        end
        print(t.a)  -- nil
        setmetatable(t, {__index = __index})
        print(t.a)  -- __index {} a 0
        print(t[1]) -- __index {} 1 0
        ```
        用来解决Matrix的索引问题：旧方法想使用矩阵m的内容，只能`Matrix.get(m, i, j)`而不能`m[i][j]`
        ```lua
        local Matrix = {}

        function Matrix.new(r, c)
           local t = {r = r, c = c, data = {}}
           for i = 1, r do
              data[i] = {}
              for j = 1, c do
                 data[i][j] = 0
              end
           end
           --对t进行方法调用时，实际上调用了Matrix中的内容
           setmetatable(t, {__index = Matrix})
           return t
        end

        function Matrix.get(m, i, j)
           return m.data[i][j]
        end

        -- How can we get around the gross m.get(m) issue? Next week!
        local m = Matrix.new(2, 3)
        -- m.get 实际上是Matrix.get
        -- 从而对使用者而言Matrix是透明的，对m进行index只涉及到m
        print(m.get(m, 1, 1))
        ```

     2. iterator
        for循环对iterator也起作用
        下面这段代码prime_numbers()返回的是一个“每调用一次返回下一个质数”的函数
        该函数作为iterator，每一轮循环开始执行一次iterator，获取返回值传给p，直到返回nil(不返回值也将继续执行)
        由于iterator作用域在prime_numbers()内，其中的变量i始终有效，从而每次打印的质数p会递增

        ```lua
        function prime_numbers()
          local i = 2
          return function()
            while true do
              local is_prime = true
              for j = 2, i / 2 do
                if i % j == 0 then
                  is_prime = false
                  break
                end
              end

              local j = i
              i = i + 1

              if is_prime then
                return nil
              end
            end
          end
        end

        for p in prime_numbers() do
          print(p)
        end
        ```

   * **在 [`lua.lua`](../code/lua.lua#L298) 的Exercise 里, `fib[n]` 的时间复杂度如何? 如何改进? 请给出时间复杂度为 O(n) 的算法(用 Lua 写), 要求仍能够以 `fib[n]` 的形式调用.**

     *Answer:*

     时间复杂度$O(2^N)$
     改进：动态规划

     ```lua
     fib = {}
     do
         --在局部域声明rst
         --rst中存放斐波那契数列的实际结果
         --fib[i]先在rst中查找，否则递归计算
         local rst = {}
         function __index(fib, i)
             if rst[i] == nil then
                 --print("query rst", i) --debug purpose，验证是否每项只计算一次
                 if i == 1 or i == 2 then
                     rst[i] = 1
                 else
                     rst[i] = fib[i - 1] + fib[i - 2]
                 end
             end
             return rst[i]
         end
         setmetatable(fib, {__index = __index})
     end
     print(fib[10])
     ```

2. **在 [Part 1, Serialization](#part-1-serialization), 你可能会试图写类似如下的代码**

   ```lua
   str = ""
   for k, v in pairs(t) do
       str = str .. k .. v
   end
   ```

   **请问这样的代码存在什么问题（分析时间复杂度)? 如何改进?**

   *Answer:*

   在lua中，字符串是不可被改变的，每次对字符串变量进行操作实际上是将其指向了一个新的字符串。

   上述代码中，每次拼接k、v均将str重新复制了一份。若共有n个pair，每对pair长度为k，复杂度则为$O(kn^2)$

   改进方法：将每个pair存于table中，使用二分法依次拼接，复杂度为$O(knlog(n))$

   ```lua
   str = ""
   storage = {}
   index = 1
   for k, v in pairs(t) do
       storage[index] = k .. v
       index += 1
   end
   function joint(start, stop)
       if start == stop then
           return storage[start]
       else
           return joint(start, (start + stop)/2) .. joint(math.floor((start + stop)/2 + 1), stop)
       end
   end
   str = joint(1, index - 1)
   ```

3. **在 [Part 2: RPC](#part-2-rpc), 你需要实现 `inst.k_async()` 函数, 虽然函数名字里有 async (异步), 但仍然是阻塞式的调用. 如果要改成非阻塞式, 应该怎么做?**

   *Answer:*

   在to_child_pipe中向child进程发送指令后直接返回，每次获取结果时parent向to_parent_pipe发送消息，然后在这个pipe中读取，如果收到的消息是自己发送的，则child未回复，否则为method k的返回值