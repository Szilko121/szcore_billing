local Billing={};local locks={};local rate={}
local function p(src)return exports.szcore:GetPlayer(src)end
local function online(cid)return exports.szcore:GetPlayerByCitizenId(cid)end
local function notifyCid(cid,text,typ)local q=online(cid);if q then TriggerClientEvent('szcore_ui:notify',q.PlayerData.source,{type=typ or 'info',description=text})end end
local function allowed(src,key,ms)local n=GetGameTimer();rate[src]=rate[src] or {};local x=rate[src][key] or 0;if n-x<ms then return false end;rate[src][key]=n;return true end
local function canIssue(player)
    if SzCoreBillingConfig.allowPersonalInvoices then return true end
    local j=player.PlayerData.job;if not j or j.name=='unemployed' or not j.onduty then return false end
    return j.boss or player.hasPermission(j.name..'.billing') or player.hasPermission('billing.issue')
end
function Billing.create(issuer,targetCid,value,label,society)
    local amount=exports.szcore:ValidateInteger(value,1,SzCoreBillingConfig.maxAmount);if not amount then return nil,'invalid_amount' end
    if issuer==targetCid then return nil,'same_player' end
    if type(label)~='string' or #label<1 or #label>128 then return nil,'invalid_label'end
    if type(targetCid)~='string' or targetCid=='' then return nil,'invalid_target' end
    if not MySQL.scalar.await('SELECT 1 FROM szcore_characters WHERE citizenid=?',{targetCid}) then return nil,'target_not_found' end
    local id=MySQL.insert.await("INSERT INTO szcore_bills (issuer_citizenid,target_citizenid,society,amount,label,status) VALUES (?,?,?,?,?,'unpaid')",{issuer,targetCid,society,amount,label or 'Számla'})
    if id then notifyCid(targetCid,('Új számlád érkezett: %s ($%d)'):format(label or 'Számla',amount),'info') end
    return id
end
function Billing.createForPlayer(source,targetSource,value,label,society)
    local issuer,target=p(source),p(targetSource);if not issuer or not target then return nil,'player_not_found' end
    if not canIssue(issuer) then return nil,'no_permission' end
    if not exports.szcore:ValidateDistance(source,targetSource,SzCoreBillingConfig.issueDistance) then return nil,'target_too_far' end
    local soc=society or issuer.PlayerData.job.name
    if soc and soc~=issuer.PlayerData.job.name and not issuer.hasPermission('billing.any') then return nil,'invalid_society' end
    return Billing.create(issuer.PlayerData.citizenid,target.PlayerData.citizenid,value,label,soc)
end
function Billing.pay(source,id)return exports.szcore:PayInvoiceAtomic(source,id)end
function Billing.cancel(source,id)
    local player=p(source);id=tonumber(id);if not player or not id then return false,'invalid_request' end
    local b=MySQL.single.await("SELECT issuer_citizenid,status FROM szcore_bills WHERE id=?",{id});if not b or b.status~='unpaid' then return false,'bill_not_found' end
    if b.issuer_citizenid~=player.PlayerData.citizenid and not player.hasPermission('billing.cancel') then return false,'not_issuer' end
    local ok=MySQL.update.await("UPDATE szcore_bills SET status='cancelled' WHERE id=? AND status='unpaid'",{id})>0
    if ok then exports.szcore:Audit('billing.cancel',source,id,{})end
    return ok
end
function Billing.list(cid,status,direction)
    local where=direction=='sent' and 'issuer_citizenid=?' or 'target_citizenid=?';local params={cid}
    if status then where=where..' AND status=?';params[#params+1]=status end
    return MySQL.query.await('SELECT * FROM szcore_bills WHERE '..where..' ORDER BY id DESC LIMIT '..math.min(SzCoreBillingConfig.pageLimit,200),params) or {}
end
local function overview(source)
    local player=p(source);if not player then return nil,'player_not_found' end
    local near={}
    for _,sid in ipairs(exports.szcore:GetPlayerSources()) do if sid~=source and exports.szcore:ValidateDistance(source,sid,SzCoreBillingConfig.issueDistance) then local q=p(sid);if q then near[#near+1]={source=sid,name=q.PlayerData.name,citizenid=q.PlayerData.citizenid}end end end
    return {received=Billing.list(player.PlayerData.citizenid,nil,'received'),sent=Billing.list(player.PlayerData.citizenid,nil,'sent'),nearby=near,canIssue=canIssue(player),job=player.PlayerData.job,bank=player.PlayerData.money.bank}
end
local function action(source,action,data)
    if not allowed(source,'action',180)then return false,'rate_limited'end;data=type(data)=='table'and data or{}
    if action=='pay'then return Billing.pay(source,data.id)
    elseif action=='cancel'then return Billing.cancel(source,data.id)
    elseif action=='create'then local id,err=Billing.createForPlayer(source,tonumber(data.target),data.amount,data.label,data.society);return id~=nil,err,id end
    return false,'invalid_action'
end
exports('CreateBill',Billing.create);exports('CreateBillForPlayer',Billing.createForPlayer);exports('PayBill',Billing.pay);exports('CancelBill',Billing.cancel);exports('GetBills',Billing.list)
exports.szcore:CreateCallback('szcore_billing:overview',overview);exports.szcore:CreateCallback('szcore_billing:action',action)
AddEventHandler('playerDropped',function()rate[source]=nil end)
