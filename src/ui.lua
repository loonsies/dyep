local mobStatus = {
    normal = 1,
    weaponskill = 2,
    casting = 3,
    stunned = 4,
    [1] = 'Normal',
    [2] = 'Weaponskill',
    [3] = 'Casting',
    [4] = 'Stunned'
}

ui = {}
lastSpell = 'None'
targetStatus = mobStatus.normal

ui.maxLabelWidth = 0

local time = require 'ffxi.time'

local day_spells = {
    { day = 'Firesday',     spells = { 'Fire III', 'Fire IV', 'Firaga III', 'Flare', 'Katon: Ni', 'Ice Threnody', 'Heat Breath' } },
    { day = 'Earthsday',    spells = { 'Stone III', 'Stone IV', 'Stonega III', 'Quake', 'Doton: Ni', 'Lightning Threnody', 'Magnetite Cloud' } },
    { day = 'Watersday',    spells = { 'Water III', 'Water IV', 'Waterga III', 'Flood', 'Suiton: Ni', 'Fire Threnody', 'Maelstrom' } },
    { day = 'Windsday',     spells = { 'Aero III', 'Aero IV', 'Aeroga III', 'Tornado', 'Huton: Ni', 'Earth Threnody', 'Mysterious Light' } },
    { day = 'Iceday',       spells = { 'Blizzard III', 'Blizzard IV', 'Blizzaga III', 'Freeze', 'Hyoton: Ni', 'Wind Threnody', 'Ice Break' } },
    { day = 'Lightningday', spells = { 'Thunder III', 'Thunder IV', 'Thundaga III', 'Burst', 'Raiton: Ni', 'Water Threnody', 'Mind Blast' } },
    { day = 'Lightsday',    spells = { 'Banish II', 'Banish III', 'Banishga II', 'Holy', 'Flash', 'Dark Threnody', 'Radiant Breath' } },
    { day = 'Darksday',     spells = { 'Drain', 'Aspir', 'Dispel', 'Bio II', 'Kurayami: Ni', 'Light Threnody', 'Eyes On Me' } },
}

if not dyep.claimedDayIndex then
    dyep.claimedDayIndex = nil
end

function ui.drawUI()
    if imgui.Begin('doubleyellowexclamationpoint', dyep.visible, ImGuiWindowFlags_AlwaysAutoResize) then
        -- Color the status if not normal
        local statusText = string.format('Target status: %s', mobStatus[targetStatus] or 'Unknown')
        if targetStatus ~= mobStatus.normal then
            local color = { 1.0, 0.5, 0.2, 1.0 } -- default abnormal (orange)
            if targetStatus == mobStatus.weaponskill then
                color = { 1.0, 0.4, 0.2, 1.0 } -- orange-red for weaponskill
            elseif targetStatus == mobStatus.casting then
                color = { 0.2, 0.6, 1.0, 1.0 } -- blue for casting
            elseif targetStatus == mobStatus.stunned then
                color = { 1.0, 0.2, 0.2, 1.0 } -- red for stunned
            end
            imgui.PushStyleColor(imgui.Col.Text, color)
            imgui.Text(statusText)
            imgui.PopStyleColor()
        else
            imgui.Text(statusText)
        end
        imgui.Text(string.format('Last spell used: %s', lastSpell))
        imgui.Text(string.format('Claimed by: %s', utils.getPartyClaimerName(utils.getTarget())))

        local mp = utils.getMP()
        imgui.Text(string.format('MP: %i', mp))

        if imgui.Button('Reset') then
            lastSpell = 'None'
            targetStatus = mobStatus.normal
            utils.resetFirstClaimHolder()
            utils.resetClickedButtons()
            dyep.claimedDayIndex = nil
        end
        imgui.Separator()

        local spellsPerLine = 4
        -- Determine the claimed day index: always refresh if not claimed, or if no target
        local targetId = utils.getTarget()
        if not dyep.claimedDayIndex or not targetId or targetId == 0 then
            dyep.claimedDayIndex = time.get_game_weekday() -- 0-based
        end

        -- Get indices for previous, current, and next day (0-based)
        local function wrapDay(idx)
            return (idx + 8) % 8
        end
        local prev = wrapDay(dyep.claimedDayIndex - 1)
        local curr = dyep.claimedDayIndex
        local nextd = wrapDay(dyep.claimedDayIndex + 1)

        -- Show spells for previous, current, and next day, grouped by day
        local day_indices = { prev, curr, nextd }
        local ImGuiCol_Button = _G.ImGuiCol_Button or 7
        local ImGuiCol_ButtonHovered = _G.ImGuiCol_ButtonHovered or 8
        local ImGuiCol_ButtonActive = _G.ImGuiCol_ButtonActive or 9
        for _, idx in ipairs(day_indices) do
            local day = day_spells[idx + 1] -- convert 0-based to 1-based for Lua tables
            if day and day.spells then
                imgui.Text(day.day)
                for i, spell in ipairs(day.spells) do
                    local isClicked = utils.clickedButtons[spell]
                    local pushedStyle = false
                    if isClicked then
                        imgui.PushStyleColor(ImGuiCol_Button, { 0.5, 0.2, 1.0, 1.0 })
                        imgui.PushStyleColor(ImGuiCol_ButtonHovered, { 0.5, 0.2, 1.0, 1.0 })
                        imgui.PushStyleColor(ImGuiCol_ButtonActive, { 0.5, 0.2, 1.0, 1.0 })
                        pushedStyle = true
                    end
                    local buttonClicked = imgui.Button(spell)
                    if buttonClicked then
                        if utils.isTargetBusy() then
                            print(chat.header(addon.name):append(chat.error('Target cannot be procced at this moment')))
                            if pushedStyle then
                                imgui.PopStyleColor(3)
                            end
                            return
                        end

                        lastSpell = spell
                        utils.castSpell(spell, 't')
                        utils.clickedButtons[spell] = true
                    end
                    if pushedStyle then
                        imgui.PopStyleColor(3)
                    end
                    if i % spellsPerLine ~= 0 then
                        imgui.SameLine()
                    end
                end
                imgui.NewLine()
            end
        end

        imgui.End()
    end
end

function ui.update()
    local now = os.clock()

    for mobId, busyUntil in pairs(utils.mobActionState) do
        if busyUntil <= now then
            utils.mobActionState[mobId] = nil
            targetStatus = mobStatus.normal
        end
    end

    local targetId = utils.getTarget()
    if not targetId or targetId == 0 then
        targetStatus = mobStatus.normal
    end

    if utils.mobActionState[targetId] and utils.mobActionState[targetId] < now then
        targetStatus = mobStatus.normal
    end

    if dyep.prevTargetHP == -1 or dyep.prevTargetID == -1 or utils.getTarget() ~= dyep.prevTargetID then
        lastSpell = 'None'
        utils.resetFirstClaimHolder()
        utils.resetClickedButtons()
    end

    if not dyep.visible[1] then
        return
    end

    ui.drawUI()
end

return ui
