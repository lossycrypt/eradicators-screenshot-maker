
local erlib = {
  Table  = {},
  String = {},
  Gui    = {},
  }

local Table  = erlib.Table
local String = erlib.String
local Gui    = erlib.Gui
local NIL    = '2a132dbfe4784627b86aa3807cd19cfeff487aab3dd7a60d0ab119a72e736936'
local SKIP   = function()end

function Table.sget(tbl,path,default) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end local k = path[n] if r[k] == nil then r[k] = default end return r[k] end
function Table.get (tbl,path,default) local r = tbl for i=1,#path do if type(r) == 'table' then r = r[ path[i] ] else return default end end if r ~= nil then return r else return default end end
function Table.set (tbl,path,value) local r = tbl local n = #path for i=1,n-1 do local k = path[i] if r[k] == nil then r[k] = {} end r = r[k] end if value == NIL then value = nil end r[path[n]] = value return value end
function Table.clear(tbl,except_keys) if not except_keys then for k in pairs(tbl) do tbl[k] = nil end return tbl else local keep = {}; for _,k in pairs(except_keys) do keep[k] = true end for k in pairs(tbl) do if not keep[k] then tbl[k] = nil end end return tbl end end
function Table.scopy(tbl);local r = {};for k,v in pairs(tbl) do r[k] = v end;return r;end
  
function String.replace(str,pattern,replacement,n,raw);if raw == false then;return string.gsub(str,pattern,replacement,n);end;local s,c = 1,0;n = n or math.huge;while n > 0 do;local i,j = string.find(str,pattern,s,true);if not i then break end;str = str:sub(1,i-1)..replacement..str:sub(j+1,-1);s = j+1;n = n-1;c = c+1;end;return str,c;end


  
--RuntimeStyle
do 
  local aliases = {'width', 'height', w = 'width', h = 'height'}
  function Gui.apply_stylers(elm, ...)
    local elm_style = elm.style
    for _, styler in pairs{ ...  } do
    for k, v      in pairs(styler) do
      elm_style[aliases[k] or k] = v
      end
      end
    return elm
  end
  end
  
  
return erlib