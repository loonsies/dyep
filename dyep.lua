addon.name = 'dyep'
addon.version = '0.1'
addon.author = 'Looney'
addon.desc = 'give me the fucking doubleyellowexclamationpoint'
addon.link = 'https://github.com/loonsies/doubleyellowexclamationpoint'

-- Ashita dependencies
require 'common'
settings = require('settings')
chat = require('chat')
imgui = require('imgui')

-- Local dependencies
actionTypes = require('data/actionTypes')
mobStatus = require('data/mobStatus')

config = require('src/config')

dyep = {
    visible = { false },
    config = config.load(),
    prevTargetHP = -1,
    prevTargetID = -1,
}

commands = require('src/commands')
ui = require('src/ui')
utils = require('src/utils')

ashita.events.register('command', 'command_cb', function (cmd, nType)
    local args = cmd.command:args()
    if #args ~= 0 then
        commands.handleCommand(args)
    end
end)

ashita.events.register('packet_in', 'packet_in_cb', function (e)
    if e.id ~= 0x028 then return end

    local ap = utils.parseActionPacket(e)

    if ap and ap.Type == 7 or ap.Type == 8 then
        if not utils.isMonster(ap.UserIndex) then return end

        local targetEntity = utils.getTarget()
        if ap.UserIndex ~= targetEntity then return end

        if ap.Type == 7 then
            targetStatus = mobStatus.weaponskill
        else
            targetStatus = mobStatus.casting
        end

        local mobId = ap.UserId
        utils.mobActionState[mobId] = os.clock() + 3
    end
end)

ashita.events.register('d3d_present', 'd3d_present_cb', function ()
    ui.update()
    local currentTarget = utils.getTarget()
    if currentTarget then
        local target = GetEntity(currentTarget)
        if target then
            if target.HPPercent ~= dyep.prevTargetHP then
                dyep.prevTargetHP = target.HPPercent
            end
            if currentTarget ~= dyep.prevTargetID then
                dyep.prevTargetID = currentTarget
            end
        else
            dyep.prevTargetHP = -1
            dyep.prevTargetID = -1
        end
    end
end)
