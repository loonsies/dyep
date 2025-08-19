commands = {}

function commands.handleCommand(args)
    local command = string.lower(args[1])
    local arg = #args > 1 and string.lower(args[2]) or ''
    local arg2 = #args > 2 and string.lower(args[3]) or ''

    if command ~= '/dyep' and command ~= '/proc' then
        return false
    end

    if arg == '' then
        dyep.visible[1] = not dyep.visible[1]
    end
end

return commands
