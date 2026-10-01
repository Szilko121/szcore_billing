local open=false
local function n(t,typ)exports.szcore_ui:Notify({description=t,type=typ or 'info'})end
local function refresh()local d=exports.szcore:AwaitCallback('szcore_billing:overview');if d and open then SendNUIMessage({action='data',data=d})end end
local function show()local d,err=exports.szcore:AwaitCallback('szcore_billing:overview');if not d then return n(err or 'Nem elérhető.','error')end;open=true;SetNuiFocus(true,true);SendNUIMessage({action='open',data=d})end
local function close()open=false;SetNuiFocus(false,false);SendNUIMessage({action='close'})end
RegisterCommand(SzCoreBillingConfig.command,show,false);RegisterKeyMapping(SzCoreBillingConfig.command,'SzCore számlák','keyboard',SzCoreBillingConfig.key)
RegisterNUICallback('close',function(_,cb)close();cb({ok=true})end)
RegisterNUICallback('action',function(d,cb)local ok,err,id=exports.szcore:AwaitCallback('szcore_billing:action',d.action,d);if ok then n(d.action=='create' and ('Számla kiállítva # '..tostring(id)) or 'Művelet sikeres.','success');refresh()else n(err or 'Sikertelen.','error')end;cb({ok=ok,error=err})end)
exports('OpenBilling',show)
