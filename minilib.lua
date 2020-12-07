
local erlib = {
  Table = {},
  }

local Table = erlib.Table


function Table.sget(tbl,path,default) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end local k = path[n] if r[k] == nil then r[k] = default end return r[k] end
function Table.get (tbl,path,default) local r = tbl for i=1,#path do if type(r) == 'table' then r = r[ path[i] ] else return default end end if r ~= nil then return r else return default end end
function Table.set (tbl,path,value) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end if value == NIL then value = nil end r[path[n]] = value return value end
  
  
function Table.clear(tbl,except_keys)
  if not except_keys then
    for k in pairs(tbl) do tbl[k] = nil end
    return tbl
  else
    local keep = {}; for _,k in pairs(except_keys) do keep[k] = true end
    for k in pairs(tbl) do if not keep[k] then tbl[k] = nil end end
    return tbl
    end
  end

return erlib