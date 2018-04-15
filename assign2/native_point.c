#define LUA_LIB
#define _GNU_SOURCE

#include <lua.h>
#include <lauxlib.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

typedef struct {
  lua_Number x;
  lua_Number y;
} point_t;

static int point_add(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    point_t* p2 = (point_t*) luaL_checkudata(L, 2, "point_native");
    point_t* p3 = (point_t*) lua_newuserdata(L, sizeof(point_t));
    p3->x = p1->x + p2->x;
    p3->y = p1->y + p2->y;
    luaL_setmetatable(L, "point_native");
    return 1;
}

static int point_dist(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    point_t* p2 = (point_t*) luaL_checkudata(L, 2, "point_native");
    double r = sqrt((p1->x - p2->x) * (p1->x - p2->x) + (p1->y - p2->y) * (p1->y - p2->y));
    lua_pushnumber(L, r);
    // luaL_getmetatable(L, "point_native");
    // lua_setmetatable(L, -2);
    // luaL_setmetatable(L, "point_native");
    return 1;
}

static int point_eq(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    point_t* p2 = (point_t*) luaL_checkudata(L, 2, "point_native");
    if (p1->x == p2->x && p1->y == p2->y) {
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    // luaL_setmetatable(L, "point_native");
    return 1;
}


static int point_sub(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    point_t* p2 = (point_t*) luaL_checkudata(L, 2, "point_native");
    point_t* p3 = (point_t*) lua_newuserdata(L, sizeof(point_t));
    p3->x = p1->x - p2->x;
    p3->y = p1->y - p2->y;
    luaL_setmetatable(L, "point_native");
    return 1;
}

static int point_x(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    lua_pushnumber(L, p1->x);
    return 1;
}

static int point_y(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    lua_pushnumber(L, p1->y);
    return 1;
}

static int point_setx(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    double x = luaL_checknumber(L, 2);
    p1->x = x;
    return 0;
}

static int point_sety(lua_State* L) {
    // Your code here.
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    double y = luaL_checknumber(L, 2);
    p1->y = y;
    return 0;
}

static int point_new(lua_State* L) {
    // Your code here.
    // double* x = luaL_checkint();
    point_t* t = lua_newuserdata(L, sizeof(point_t));
    double x = luaL_checknumber(L, 1);
    double y = luaL_checknumber(L, 2);
    // double y = (double*) luaL_checkudata(L, 2, "number");
    t->x = x;
    t->y = y;
    // luaL_getmetatable(L, "point_native");
    // lua_setmetatable(L, -1);
    luaL_setmetatable(L, "point_native");
    return 1;
}

static int point_tostring(lua_State* L) {
    // Your code here. 
    point_t* p1 = (point_t*) luaL_checkudata(L, 1, "point_native");
    // char* c;
    // sprintf(c, "??", p1->x, p1->y);
    lua_pushfstring(L, "{%d, %d}", (int)p1->x, (int)p1->y);
    // luaL_getmetatable(L, "point_native");
    return 1;
}

int luaopen_native_point(lua_State* L) {
  // Create the metatable that describes the behaviour of every point object.
  luaL_newmetatable(L, "point_native");

  // Add _, -, =, and tostring metamethods.
  {
    lua_pushstring(L, "__add");
    lua_pushcfunction(L, point_add);
    lua_settable(L, -3);

    lua_pushstring(L, "__sub");
    lua_pushcfunction(L, point_sub);
    lua_settable(L, -3);

    lua_pushstring(L, "__eq");
    lua_pushcfunction(L, point_eq);
    lua_settable(L, -3);

    lua_pushstring(L, "__tostring");
    lua_pushcfunction(L, point_tostring);
    lua_settable(L, -3);
  }

  // Create class table with a new method.
  lua_createtable(L, 1, 0);
  lua_pushstring(L, "new");
  lua_pushcfunction(L, point_new);
  lua_settable(L, -3);

  // Add Dist, X, Y, SetX, and SetY methods to class table.
  {
    lua_pushstring(L, "Dist");
    lua_pushcfunction(L, point_dist);
    lua_settable(L, -3);

    lua_pushstring(L, "X");
    lua_pushcfunction(L, point_x);
    lua_settable(L, -3);

    lua_pushstring(L, "Y");
    lua_pushcfunction(L, point_y);
    lua_settable(L, -3);

    lua_pushstring(L, "SetX");
    lua_pushcfunction(L, point_setx);
    lua_settable(L, -3);

    lua_pushstring(L, "SetY");
    lua_pushcfunction(L, point_sety);
    lua_settable(L, -3);
  }

  // Set the class table to the point metatable's __index.
  lua_pushstring(L, "__index");
  lua_pushvalue(L, -2);
  lua_settable(L, -4);

  // Only return one value at the top of the stack, which is the Point class
  // table.

  return 1;
}
