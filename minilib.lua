
local erlib = {
  Table = {},
  }

local Table = erlib.Table


function Table.sget(tbl,path,default) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end local k = path[n] if r[k] == nil then r[k] = default end return r[k] end
function Table.get (tbl,path,default) local r = tbl for i=1,#path do if type(r) == 'table' then r = r[ path[i] ] else return default end end if r ~= nil then return r else return default end end
function Table.set (tbl,path,value) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end if value == NIL then value = nil end r[path[n]] = value return value end
  

return erlib