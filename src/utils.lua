utils = {}

utils.clickedButtons = {}
utils.mobActionState = T {}
utils.firstClaimHolder = nil

function utils.getDistance()
    local targetMgr = AshitaCore:GetMemoryManager():GetTarget()
    local mainTarget = targetMgr:GetTargetIndex(0)
    local entity = GetEntity(mainTarget)
    if entity == nil then
        return -1
    end
    local distance = entity.Distance:sqrt()

    return distance
end

function utils.getTarget()
    local targetMgr = AshitaCore:GetMemoryManager():GetTarget()
    local currentTarget = targetMgr:GetTargetIndex(0)
    return currentTarget
end

function utils.getMP()
    local entMgr = AshitaCore:GetMemoryManager():GetEntity()
    local partyMgr = AshitaCore:GetMemoryManager():GetParty()

    if entMgr ~= nil and partyMgr ~= nil then
        local mp = partyMgr:GetMemberMP(0)
        return mp
    end

    return 0
end

function utils.canCastSpell(spell)
    local spellRes = AshitaCore:GetResourceManager():GetSpellByName(spell, 0)
    local recastMgr = AshitaCore:GetMemoryManager():GetRecast()

    if spellRes == nil or recastMgr == nil then
        return false
    end
    local spellRecast = recastMgr:GetSpellTimer(spellRes.Index)

    if spellRecast == 0 and utils.getMP() >= spellRes.ManaCost then
        return true
    end

    return false
end

function utils.castSpell(spell, target)
    local spellRes = AshitaCore:GetResourceManager():GetSpellByName(spell, 0)

    if not spellRes or not utils.canCastSpell(spell) then
        return
    end

    print(chat.header(addon.name):append(chat.color2(200, string.format('Casting spell: %s <%s>', spellRes.Name[1], target))))
    AshitaCore:GetChatManager():QueueCommand(-1, string.format('/ma "%s" <%s>', spellRes.Name[1], target))
end

local function GetShortFlags(entityIndex)
    local fullFlags = AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(entityIndex);
    return bit.band(fullFlags, 0xFF);
end

function utils.isMonster(entityIndex)
    return GetShortFlags(entityIndex) == 0x10
end

function utils.isTargetBusy()
    local targetId = utils.getTarget()
    local ent = GetEntity(targetId)
    if not targetId or targetId == 0 or not ent then return false end

    local busyUntil = utils.mobActionState[ent.ServerId]
    if busyUntil and busyUntil > os.clock() then
        return true
    end

    return false
end

function utils.getIndexFromId(serverId)
    local index = bit.band(serverId, 0x7FF);
    local entMgr = AshitaCore:GetMemoryManager():GetEntity();
    if (entMgr:GetServerId(index) == serverId) then
        return index;
    end
    for i = 1, 2303 do
        if entMgr:GetServerId(i) == serverId then
            return i;
        end
    end
    return 0;
end

function utils.getNameOfClaimHolder(targetIndex)
    if targetIndex == nil or targetIndex <= 0 then
        return 'No target'
    end

    local entMgr = AshitaCore:GetMemoryManager():GetEntity()
    if entMgr == nil then
        return 'Error'
    end

    local claimStatus = entMgr:GetClaimStatus(targetIndex)
    if claimStatus == 0 then
        return 'None'
    end

    if utils.firstClaimHolder ~= nil then
        return utils.firstClaimHolder
    end

    local partyMgr = AshitaCore:GetMemoryManager():GetParty()
    if partyMgr == nil then
        return 'Error'
    end

    for i = 0, 17 do
        if partyMgr:GetMemberIsActive(i) == 1 and partyMgr:GetMemberServerId(i) == claimStatus then
            local memberEntityIndex = utils.getIndexFromId(claimStatus)
            if memberEntityIndex and memberEntityIndex ~= 0 then
                local name = string.format('%s [%i]', entMgr:GetName(memberEntityIndex), partyMgr:GetMemberServerId(i))
                utils.firstClaimHolder = name
                return name
            else
                return nil
            end
        end
    end

    return 'Outside of party'
end

function utils.getPartyClaimerName(targetIndex)
    local name = utils.getNameOfClaimHolder(targetIndex)
    if name == nil or name == '' then
        return 'Unknown'
    end
    return name
end

local bitData;
local bitOffset;
local function UnpackBits(length)
    local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
    bitOffset = bitOffset + length;
    return value;
end

function utils.parseActionPacket(e)
    local ap = T {}
    bitData = e.data_raw
    bitOffset = 40

    ap.UserId = UnpackBits(32)
    ap.UserIndex = utils.getIndexFromId(ap.UserId)
    local targetCount = UnpackBits(6)
    bitOffset = bitOffset + 4 -- unknown 4 bits
    ap.Type = UnpackBits(4)
    ap.Id = UnpackBits(32)
    bitOffset = bitOffset + 32 -- unknown 32 bits

    ap.Targets = T {}
    for i = 1, targetCount do
        local target = T {}
        target.Id = UnpackBits(32)
        local actionCount = UnpackBits(4)
        target.Actions = T {}
        for j = 1, actionCount do
            local action = {}
            action.Reaction = UnpackBits(5)
            action.Animation = UnpackBits(12)
            action.SpecialEffect = UnpackBits(7)
            action.Knockback = UnpackBits(3)
            action.Param = UnpackBits(17)
            action.Message = UnpackBits(10)
            action.Flags = UnpackBits(31)

            local hasAdditionalEffect = (UnpackBits(1) == 1)
            if hasAdditionalEffect then
                UnpackBits(10) -- Damage
                UnpackBits(17) -- Param
                UnpackBits(10) -- Message
            end

            local hasSpikesEffect = (UnpackBits(1) == 1)
            if hasSpikesEffect then
                UnpackBits(10) -- Damage
                UnpackBits(14) -- Param
                UnpackBits(10) -- Message
            end

            target.Actions:append(action)
        end
        ap.Targets:append(target)
    end
    return ap
end

function utils.weaponskill(name, buttonId)
    if utils.isTargetBusy() then
        print(chat.header(addon.name):append(chat.error('Target cannot be procced at this moment')))
        return
    end

    if not utils.canUseWeaponskill(name) then
        print(chat.header(addon.name):append(chat.error('Cannot use weaponskill')))
        return
    end

    AshitaCore:GetChatManager():QueueCommand(-1, string.format('/ma "%s" <t>', name))

    utils.clickedButtons[buttonId] = true
end

function utils.getEquippedItemId(slot)
    local inventory = AshitaCore:GetMemoryManager():GetInventory()

    if not inventory then
        return nil, nil
    end

    local equipment = inventory:GetEquippedItem(slot)

    if not equipment then
        return nil, nil
    end

    local index = equipment.Index

    if index == nil or index == 0 then
        return nil, nil
    end

    local bag = 0

    if index < 2048 then
        bag = 0
    elseif index < 2560 then
        bag = 8
        index = index - 2048
    elseif index < 2816 then
        bag = 10
        index = index - 2560
    elseif index < 3072 then
        bag = 11
        index = index - 2816
    elseif index < 3328 then
        bag = 12
        index = index - 3072
    elseif index < 3584 then
        bag = 13
        index = index - 3328
    elseif index < 3840 then
        bag = 14
        index = index - 3584
    elseif index < 4096 then
        bag = 15
        index = index - 3840
    elseif index < 4352 then
        bag = 16
        index = index - 4096
    end

    local containerItem = inventory:GetContainerItem(bag, index)
    if containerItem ~= nil and containerItem.Id ~= 0 then
        return containerItem.Id, bag
    end

    return nil, nil
end

function utils.weapon(name, weaponType, buttonId)
    AshitaCore:GetChatManager():QueueCommand(-1, string.format('/equip main "%s"', name))

    ashita.tasks.once(1, function ()
        local itemId, bag = utils.getEquippedItemId(0)

        if itemId ~= nil and itemId ~= 0 then
            local item = AshitaCore:GetResourceManager():GetItemById(itemId)

            if item ~= nil and item.Name ~= nil and item.Name[1] ~= nil then
                if item.Name[1] == name then
                    utils.clickedButtons[buttonId] = true
                    print(chat.header(addon.name):append(chat.success(string.format('Equipped %s successfully', name))))
                else
                    print(chat.header(addon.name):append(chat.error(string.format('Equipped item mismatch. Expected: %s, Found: %s', name, item.Name[1]))))
                end
            else
                print(chat.header(addon.name):append(chat.error(string.format('Could not resolve equipped item after equipping %s', name))))
            end
        else
            print(chat.header(addon.name):append(chat.error(string.format('No main weapon equipped after trying to equip %s', name))))
        end
    end)
end

function utils.labeledInput(label, inputId, inputTable)
    local labelWidth = imgui.CalcTextSize(label)
    if labelWidth > ui.maxLabelWidth then
        ui.maxLabelWidth = labelWidth
    end

    local flags = nil
    if dyep.config.locked[1] then
        flags = ImGuiInputTextFlags_ReadOnly
    end

    imgui.SetNextItemWidth(200)
    local changed = imgui.InputText(inputId, inputTable, 48, flags)
    imgui.SameLine()

    if inputTable[1] == currentWeapon then
        imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 0.0, 1.0 })
    end

    imgui.Text(label)

    if inputTable[1] == currentWeapon then
        imgui.PopStyleColor()
    end

    if changed then
        settings.save()
    end
end

function utils.coloredButton(label, id, actionType)
    local clicked = false
    local isClicked = utils.clickedButtons[id]

    local purple = { 0.5, 0.0, 0.5, 1.0 }
    local red = { 0.76, 0.22, 0.13, 1.0 }

    local buttonColor = isClicked and purple or red

    imgui.PushStyleColor(ImGuiCol_Button, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonHovered, buttonColor)
    imgui.PushStyleColor(ImGuiCol_ButtonActive, buttonColor)

    if imgui.Button(label .. '##' .. id) then
        clicked = true
    end

    imgui.PopStyleColor(3)
    return clicked
end

function utils.resetClickedButtons()
    utils.clickedButtons = {}
end

function utils.resetFirstClaimHolder()
    utils.firstClaimHolder = nil
end

return utils
