
local erlib = {
  Table = {},
  String = {},
  }

local Table = erlib.Table
local String = erlib.String

local string_gsub, string_find = 
      string.gsub, string.find

function Table.sget(tbl,path,default) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end local k = path[n] if r[k] == nil then r[k] = default end return r[k] end
function Table.get (tbl,path,default) local r = tbl for i=1,#path do if type(r) == 'table' then r = r[ path[i] ] else return default end end if r ~= nil then return r else return default end end
function Table.set (tbl,path,value) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end if value == NIL then value = nil end r[path[n]] = value return value end
function Table.clear(tbl,except_keys) if not except_keys then for k in pairs(tbl) do tbl[k] = nil end return tbl else local keep = {}; for _,k in pairs(except_keys) do keep[k] = true end for k in pairs(tbl) do if not keep[k] then tbl[k] = nil end end return tbl end end
  
  
function String.replace(str,pattern,replacement,n,raw)
  -- Non-raw mode is faster with native gsub.
  if raw == false then
    return string_gsub(str,pattern,replacement,n)
    end
  -- Raw mode requested by Reika.
  local s,c = 1,0
  n = n or math.huge
  while n > 0 do
    local i,j = string_find(str,pattern,s,true) -- always raw
    if not i then break end
    str = str:sub(1,i-1)..replacement..str:sub(j+1,-1)
    s = j+1
    n = n-1
    c = c+1
    end
  return str,c
  end
  
  
  
  
return erlib