-- ItemRackQueue.lua
local _

function ItemRack.PeriodicQueueCheck()
	if SpellIsTargeting() then
		return
	end
	if ItemRackUser.EnableQueues=="ON" then
		for i,v in pairs(ItemRack.GetQueuesEnabled()) do
			if v and v == true then
				ItemRack.ProcessAutoQueue(i)
			end
		end
	end
end

function ItemRack.ProcessAutoQueue(slot)
	if not slot or IsInventoryItemLocked(slot) then
		return
	end

	local start,duration,enable = GetInventoryItemCooldown("player",slot)
	local timeLeft = math.max(start + duration - GetTime(),0)
	local baseID = ItemRack.GetIRString(GetInventoryItemLink("player",slot),true,true)
	local icon = _G["ItemRackButton"..slot.."Queue"]

	if not baseID then return end

	local buff = GetItemSpell(baseID)
	if buff then
		if AuraUtil.FindAuraByName(buff,"player") then
			icon:SetDesaturated(true)
			return
		end
	end

	if ItemRackItems[baseID] then
		if ItemRackItems[baseID].keep then
			icon:SetVertexColor(1,.5,.5)
			return -- leave if .keep flag set on this item
		end
		if ItemRackItems[baseID].delay then
			-- Leave item equipped if remaining cd for the item is less than its delay
			if start>0 and timeLeft>30 and timeLeft<=ItemRackItems[baseID].delay then
				icon:SetDesaturated(true)
				return
			end
		end
	end
	icon:SetDesaturated(false)
	icon:SetVertexColor(1,1,1)

	local ready = ItemRack.ItemNearReady(baseID)
	if ready and ItemRack.CombatQueue[slot] then
		ItemRack.CombatQueue[slot] = nil
		ItemRack.UpdateCombatQueue()
	end

	local list = ItemRack.GetQueues()[slot]

	local lowestCdCandidate
	local candidate
	local candidate,bag
	
	--find trinket with lowest cd	
	for i=1,#(list) do
		candidate = string.match(list[i],"(%d+)") --FIXME: not sure what list[i] is; it might simply be cleaning up some sort of slot number to make sure it is numeric, OR it might actually be an itemID... if it is the latter then this (conversion to baseID) should be handled by either ItemRack.GetIRString(list[i],true) if list[i] is an ItemRack-style ID or ItemRack.GetIRString(list[i],true,true) if list[i] is a regular ItemLink/ItemString, MOST things point to it being an ItemRack-style ID, but I do not want to mess anything up if this is in fact just a regular number, so I'll leave the line as it is
		
		if list[i]==0 then break end --if you reached the "Stop Queue Here" mark, stop looking  (i think?)
		
		if not lowestCdCandidate then lowestCdCandidate = candidate end --if nothing is set as lowest, this candidate is the new benchmark
		
		if ItemRack.ItemNearReady(candidate) then lowestCdCandidate = candidate break end --if this candidate is ready to equip, stop looking for a new candidate. this list seraches from the top of your queue to the bottom, so this ensures you always equip your highest queue item if it is ready
		
		if ItemRack.GetCD(candidate) < ItemRack.GetCD(lowestCdCandidate) then lowestCdCandidate = candidate end --if this is lower than the lowest, this is the new benchmark
		
	end
	
	
	--equip trinket with lowest cd
	if not (ready and lowestCdCandidate==baseID) then --idk, it was in the original code. i don't think it should ever fire, but who knows
	
		if not ready or enable==0 or (ItemRackItems[lowestCdCandidate] and ItemRackItems[lowestCdCandidate].priority) then --only if your current trinket is not ready, or other edge cases
		
			if GetItemCount(lowestCdCandidate)>0 and not IsEquippedItem(lowestCdCandidate) then --if it's not already equipped,
			
			_,bag = ItemRack.FindItem(lowestCdCandidate)
				if bag then
					if ItemRack.CombatQueue[slot]~=lowestCdCandidate then
						ItemRack.EquipItemByID(lowestCdCandidate,slot)
					end
				end
			end
		end
	end
	
end

function ItemRack.ItemNearReady(id)
	if start==0 or ItemRack.GetCD(id)<=30 then --if no cooldown, or cooldown is less than 30 seconds, the trinket is ready
		return true
	end
end

function ItemRack.GetCD(id)
	local start,duration = GetItemCooldown(id)
	
	return math.max(start + duration - GetTime(),0) --weird syntax, thanks blizzard: https://wowpedia.fandom.com/wiki/API_GetItemCooldown
	
end

function ItemRack.SetQueue(slot,newQueue)
	if not newQueue then
		ItemRack.GetQueuesEnabled()[slot] = nil
	elseif type(newQueue)=="table" then
		ItemRack.GetQueues()[slot] = ItemRack.GetQueues()[slot] or {}
		for i in pairs(ItemRack.GetQueues()[slot]) do
			ItemRack.GetQueues()[slot][i] = nil
		end
		for i=1,#(newQueue) do
			table.insert(ItemRack.GetQueues()[slot],newQueue[i])
		end
		if ItemRackOptFrame:IsVisible() then
			if ItemRackOptSubFrame7:IsVisible() and ItemRackOpt.SelectedSlot==slot then
				ItemRackOpt.SetupQueue(slot)
			else
				ItemRackOpt.UpdateInv()
			end
		end
		ItemRack.GetQueuesEnabled()[slot] = true
	end
	ItemRack.UpdateCombatQueue()
end
