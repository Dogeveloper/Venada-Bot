--[[
    

 __      __                  _       ____   ____ _______ 
 \ \    / /                 | |     |  _ \ / __ \__   __|
  \ \  / /__ _ __   __ _  __| | __ _| |_) | |  | | | |   
   \ \/ / _ \ '_ \ / _` |/ _` |/ _` |  _ <| |  | | | |   
    \  /  __/ | | | (_| | (_| | (_| | |_) | |__| | | |   
     \/ \___|_| |_|\__,_|\__,_|\__,_|____/ \____/  |_|   
                                                         
                                                         
by Monsieur_Robert

]]

local discordia = require('discordia')
local http = require('coro-http')
local json = require('json')
local fs = require('fs') -- file system
local client = discordia.Client()
local prefix = "-"

local statusRotations = {
    "Made by Monsieur_Robert!",
    "712 lines of code!"
}
local helpStatus = "Prefix " .. prefix .. " | "
local statusRotationDelay = 15 -- seconds

--[[
    Data structure:
    User Id, {Channel, CommandName, AnswerTable}
]]
local prompts = {}


--[[
    Function for debugging the bot.
    Credits to: https://stackoverflow.com/questions/9168058/how-to-dump-a-table-to-console
]]
function debug.dumptable(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. debug.dumptable(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end

 local dbFile = "venadabot.json" -- database file name

  --[[
     Used for the bot's database. Values can be changed or read from using the table, and they will be automatically be synchronized with the database file.

     Data is a proxy table, so new values should never be entered into it without calling the metamethods below.
 ]]

 -- but first, create the database file on startup if it doesn't already exist.
if fs.existsSync(dbFile) == false then
    fs.openSync(dbFile, "w") -- this will yield the script until the file is created
end

 -- configure the data proxy table to sync with the database file
 local data = setmetatable({}, {
    __index = function(tab, key) -- on file read
        local fi = fs.openSync(dbFile, "r+")
        local db = json.parse(fs.readFileSync(dbFile)) or {}
        fs.closeSync(fi)
        local keyArray = key:split(".")
        local previousLevel = db
        for _,key in pairs(keyArray) do
            previousLevel = previousLevel[key]
        end
        return previousLevel or {}
    end,
    __newindex = function(tab, key, value) -- on file write
        print("newindex was called")
       local fi = fs.openSync(dbFile, "r+")
       local oldData = json.parse(fs.readFileSync(dbFile)) or {}
       oldData[key] = value
       print("attempting to write " .. debug.dumptable(oldData))
       fs.writeFileSync(dbFile, oldData)
       fs.closeSync(fi)
    end
    
 })


--[[
    Lua implementation of the ternary operator. Only supports two values, the first one if true and the second one if false.
    By Robert.
]]
local function ternary(condition, obj1, obj2)
    if condition then return obj1 else return obj2 end
end

local function argsToMessage(indexToRemove, args)
    local str = ""
    local clonedArgs = {table.unpack(args)} -- deep copy the args table, quick and dirty way to do this.
    for i,v in pairs(clonedArgs) do
        if i < indexToRemove then
            table.remove(clonedArgs, i)
        end
    end -- remove command name and args not part of the message
    for i,v in pairs(clonedArgs) do
        str = str .. v
        if i == #clonedArgs then
            -- added to later
        else
            str = str .. " "
        end
    end
    return str
end

local venadaChannel = {
    corporateCommands = "702638206939824249",
    leadershipCommands = "712433741523320932",
    botCommands = "543854237013114952",
    botSpeak = "703365194994417864",
    directMessages = "-1" -- magic int used to represent something sent through a direct message.
}

local context = { -- specifies what channels a command can run in, depending on the command context.
    Corporate = {
        venadaChannel.corporateCommands,
        venadaChannel.leadershipCommands
    },
    Leadership = {
        venadaChannel.leadershipCommands
    },
    Public = {
        venadaChannel.botCommands
    },
    DirectMessages = {
        venadaChannel.directMessages
    }
}

local venadaRole = {
    MiddleRank = "618295822005698560",
    HighRank = "618295822005698560",
    SuperRank = "618295361223786508",
    Developer = "618293405931405315"
}

-- create metatables so multiple command contexts can be added together
for a,b in pairs(context) do
    local mt = {
        __add = function(tab, otherTable)
            local newTable = {}
            for i,v in pairs(tab) do
                table.insert(newTable, v)
            end
            for i,v in pairs(otherTable) do
                table.insert(newTable, v)
            end
            return newTable
        end
    }
    setmetatable(b, mt)
end

--[[
    Requires: 
    Title = Action title (such as "Reminder")
    Action = action taken (such as "Reminded")
    Color = Hex color value.
    Message = Message from Operations/Staffing.

    Returns: the embed!
]]
local function makeConsequenceEmbed(data)
    local returnTable = {
        embed = {
            title = data.Title,
            description = "You have been " .. string.lower(data.Action) .. " at Venada.",
            fields = {
                {
                    name = "Message:",
                    value = data.Message,
                    inline = true
                }
            },
            color = data.Color
        }
    }
    print(debug.dumptable(returnTable))
    return returnTable
end

--[[
    Returns true if the guild member has any of the following roles.
    Member: member
    rolesTable: table<Role>
]]
local function memberHasRoles(member, rolesTable)
    for _,role in pairs(rolesTable) do
        if member:hasRole(role) then
            return true
        end
    end
    return false
end

--[[
    Execute: function(message, args, prompts (can be nil)) REQUIRED
    Desc: Human friendly description of command.  REQUIRED
    Usage: Command usage OPTIONAL
    Argmin = minimum arguments. OPTIONAL
    Argmax = maximum arguments. OPTIONAL
    ChannelWhitelist = table of channels where this command can be ran. OPTIONAL
    PermissionValidator: function(message) = outputs no permission if the function returns false. OPTIONAL
    Prompts: table of prompts to ask the user, which will passed into prompts.

]]

local commands = {
    Testlua = {
        Execute = function(message, args)
            message.channel:send(argsToMessage(1, args))
        end,
        Desc = "Test command.",
        Usage = "N/A",
        ChannelWhitelist = context.Corporate,
        Argmin = 1,
        PermissionValidator = function()
            return false
        end
    },
    Notif = {
        Desc = "Enable or disable notifications.",
        Usage = "notif",
        ChannelWhitelist = context.Public,
        Execute = function(message, args)
            local roleId = "628733851664908298"
            if not client:getRole(roleId) then return end
            if message.member:hasRole(roleId) == false then
                message.member:addRole(roleId)
                message.channel:send({
                    embed = {
                        title = "Notifications Role Added",
                        description = "You have been added to the notifications role.",
                        color = 0x7CFC00
                    }
                })
            else
                message.member:removeRole(roleId)
                message.channel:send({
                    embed = {
                        title = "Notifications Role Removed",
                        description = "You have been removed from the notifications role.",
                        color = 0x7CFC00
                    }
                })
            end
        end,
        PermissionValidator = function(message)
            local verifiedRole = "618296385992785940"
            return message.member:hasRole(verifiedRole)
        end
    },
    Notice = {
        Desc = "Make an inactivity notice.",
        Usage = "notice",
        ChannelWhitelist = context.DirectMessages,
        Execute = function(message, args, prompts)
            print(debug.dumptable(prompts))
            if(client:getChannel("705537946480279612")) then
                local channel = client:getChannel("705537946480279612")
                channel:send{
                    embed = {
                        title = "Inactivity Notice from " .. message.author.tag,
                        description = "User ID: " .. message.author.id,
                        fields = {
                            {
                                name = "What is your username?",
                                value = prompts[1],
                                inline = false
                            },
                            {
                                name = "What is the reason for your inactivity notice?",
                                value = prompts[2],
                                inline = false
                            },
                            {
                                name = "When will your notice begin?",
                                value = prompts[3],
                                inline = false
                            },
                            {
                                name = "When will your notice end?",
                                value = prompts[4],
                                inline = false
                            },
                        },
                        color = 0xffff00
                    }
                }
            end
        end,
        PermissionValidator = function(message)
            local venadaGuild = "543853908058046466"
            if client:getGuild(venadaGuild) then
                if client:getGuild(venadaGuild):getMember(message.author.id) then
                    local member = client:getGuild(venadaGuild):getMember(message.author.id) 
                    if memberHasRoles(member, {venadaRole.MiddleRank, venadaRole.HighRank, venadaRole.SuperRank, venadaRole.Developer}) then
                        return true
                    end
                end
            end
            return false
        end,
        Prompts = {
            "What is your username?",
            "What is the reason for your inactivity notice?",
            "When will your notice begin?",
            "When will your notice end?"
        }
    },
    Remind = {
        Desc = "Remind a user.",
        Usage = "remind <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Reminder",
                    Action = "reminded",
                    Color = 0xfdfd96,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. args[1] .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Warn = {
        Desc = "Warn a user.",
        Usage = "warn <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Warning",
                    Action = "warned",
                    Color = 0xfff00,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. client:getUser(args[1]).tag .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Suspend = {
        Desc = "Suspend a user.",
        Usage = "suspend <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Suspended",
                    Action = "suspended",
                    Color = 0xffb347,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. client:getUser(args[1]).tag .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Promote = {
        Desc = "Promote a user.",
        Usage = "promote <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Promoted",
                    Action = "promoted",
                    Color = 0x77dd77,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. client:getUser(args[1]).tag .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Demote = {
        Desc = "Demote a user.",
        Usage = "demote <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Demoted",
                    Action = "demoted",
                    Color = 0xff6961,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. client:getUser(args[1]).tag .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Terminate = {
        Desc = "Terminate a user.",
        Usage = "terminate <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        Argmin = 2,
        Execute = function(message, args)
            print("Getting user id " .. args[1])
            if client:getUser(args[1]) then
                client:getUser(args[1]):getPrivateChannel():send(makeConsequenceEmbed({
                    Title = "Terminated",
                    Action = "terminated",
                    Color = 0xff0000,
                    Message = argsToMessage(2, args)
                }))
                message.channel:send("Sent to " .. client:getUser(args[1]).tag .. "!")
            else
                message.channel:send("Bad user ID.")
            end
        end
    },
    Testerror = {
        Desc = "Show bot error.",
        ChannelWhitelist = context.DirectMessages,
        PermissionValidator = function(message)
            if client.owner then
                return client.owner.id == message.author.id
            end
            return false
        end,
        Execute = function(message, args)
            error("TEST!")
        end
    },
    Dm = {
        Desc = "Send a direct message.",
        Usage = "dm",
        ChannelWhitelist = context.Corporate,
        Execute = function(message, args, prompts)
            if client:getUser(prompts[1]) then
                client:getUser(prompts[1]):getPrivateChannel():send(prompts[2])
                message.channel:send("Your direct message to " .. client:getUser(prompts[1]).tag .. " has been sent!")
            else
                message.channel:send("Bad user ID!")
            end
        end,
        Prompts = {
            "Enter user ID.",
            "Enter message."
        }
    },
    Dmtestlua = {
        Execute = function(message, args)
            message.channel:send(argsToMessage(1, args))
        end,
        Desc = "DM Test Command.",
        Usage = "N/A",
        ChannelWhitelist = context.DirectMessages,
        Argmin = 1,
        PermissionValidator = function(message)
            return false
        end
    },
    Ban = {
        Desc = "Bans a user from the Discord. Reason required. DOES NOT have to be a long reason.",
        Usage = "ban <user id> <reason>",
        ChannelWhitelist = context.Corporate + context.Public,
        PermissionValidator = function(message)
            return memberHasRoles(message.member, {venadaRole.HighRank, venadaRole.SuperRank, venadaRole.Developer})
        end,
        Argmin = 2,
        Execute = function(message, args)
            local reason = argsToMessage(2, args)
            if message.guild:getMember(args[1]) then
                local victim = message.guild:getMember(args[1])
                local banMsgSuc = victim:getPrivateChannel():send{
                    embed = {
                        title = "Banned",
                        description = "You have been banned from the Venada Discord server. This does not affect your status in the cafe.",
                        fields = {
                            {
                                name = "Reason:",
                                value = reason,
                                inline = true
                            },
                            {
                                name = "How to appeal:",
                                value = "Contact a member of the corporate team. DM Robert#0004 if you need help.",
                                inline = true
                            }
                        },
                        color = 0xff0000
                    }
                }
                local banSuccessful, err = victim:ban(reason)
                if banMsgSuc == false then
                    message.channel:send("Could not message the user about their ban. This is most likely due to strict privacy settings.")
                end
                if banSuccessful then
                    message.channel:send("Banned " .. victim.tag .. " for " .. reason .. ".")
                    if message.guild:getChannel(venadaChannel.corporateCommands) then
                        message.guild:getChannel(venadaChannel.corporateCommands):send("LOGGING: User " .. victim.tag .. " (" .. victim.id .. ") was banned by " .. message.author.tag .. " (" .. message.author.id .. ")" .. " for reason " .. reason .. ".")
                    end

                else
                    message.channel:send("Ban failed! Reason: " .. err)
                end
            else
                message.channel:send("You either entered a bad user ID, or the user is not in this guild!")
            end
        end
    },
    Unban = {
        Desc = "Unban user. A reason is needed (for example, a vote). Requires Super Rank.",
        Usage = "unban <user id> <reason>",
        ChannelWhitelist = context.Corporate,
        PermissionValidator = function(message)
            return memberHasRoles(message.member, {venadaRole.SuperRank, venadaRole.Developer})
        end,
        Argmin = 2,
        Execute = function(message, args)
            local reason = argsToMessage(2, args)
            if client:getUser(args[1]) then
                local vic = client:getUser(args[1])
                local unbanSuccessful, err = message.guild:unbanUser(vic, reason)
                if unbanSuccessful then
                    message.channel:send("Member " .. vic.tag .. " has been unbanned with reason: " .. reason)
                    local banMsgSuc, msgErr = vic:getPrivateChannel():send("You have been unbanned from the Venada Discord. You may rejoin with the invite link: https://discord.gg/wchJW8p")
                    message.guild:getChannel(venadaChannel.corporateCommands):send("LOGGING: User " .. vic.tag .. " (" .. vic.id .. ") was unbanned by " .. message.author.tag .. " (" .. message.author.id .. ")" .. " for reason " .. reason .. ".")
                    if banMsgSuc == false then
                        message.channel:send("Could not message the user about their ban. This is most likely due to strict privacy settings.")
                    end
                end
            end
        end
    },
    Randcat = {
        Desc = "Show a random cat.",
        ChannelWhitelist = context.Public + context.Corporate + context.DirectMessages,
        Execute = function(message, args)
            local suc, msg = coroutine.resume(coroutine.create(function()
                local headers, response = http.request("GET", "http://aws.random.cat/meow")
                message.channel:send{
                embed = {
                    title = "Random Cat <3",
                    image = {
                        url = json.parse(response).file,
                        width = 500,
                        height = 500,
                    },
                    color = 0xAD1818
                }
             }
             if suc == false then
                message.channel.send{
                    embed = {
                        title = "Command Failed!",
                        description = "Please try again later. The Random Cat API may be down.",
                        color = 0xff0000
                    }
                }
             end
            end))
        end
    },
    Randdog = {
        Desc = "Show a random dog.",
        ChannelWhitelist = context.Public + context.Corporate + context.DirectMessages,
        Execute = function(message, args)
            local suc, msg = coroutine.resume(coroutine.create(function()
                local headers, response = http.request("GET", "https://dog.ceo/api/breeds/image/random")
                message.channel:send{
                embed = {
                    title = "Random Dog! <3",
                    image = {
                        url = json.parse(response).message,
                        width = 500,
                        height = 500,
                    },
                    color = 0xffd700
                }
             }
             if suc == false then
                message.channel.send{
                    embed = {
                        title = "Command Failed!",
                        description = "Please try again later. The Random Dog API may be down.",
                        color = 0xff0000
                    }
                }
             end
            end))
        end
    },
    Xp = {
        Desc = "Show experience points.",
        ChannelWhitelist = context.DirectMessages,
        Execute = function(message, args)
            if data[message.author.id].xp then
                message.channel:send("You have " .. data[message.author.id].xp " points.")
            else
                message.channel:send("You have no experience points.")
            end
        end
    },
    Help = {
        Execute = function(message, args)
            local embed = {
                embed = {
                    title = "VenadaBOT Commands",
                    description = "This shows avaliable commands in this channel that you have permission for.",
                    fields = {
                        {
                            name = "Commands:",
                            value = makeCommands(message, true),
                            inline = false
                        },
                        {
                            name = "Channel:",
                            value = ternary(message.channel.type == 1, "Direct Messages", message.channel.mentionString),
                            inline = false
                        }     
                    },
                    color = 0x7CFC00
                }
            }
            local helpSuc = message.author:getPrivateChannel():send(embed)
            if message.channel.type ~= 1 then
                message.channel:send("The command list is now only sent in Direct Messages. " .. ternary(helpSuc, "Please check your direct messages. ", "The message failed to send, so please check your privacy settings and try again. ") .. message.author.mentionString)
            end
        end,    
        ChannelWhitelist = context.Corporate + context.Public + context.DirectMessages,
        Desc = "Show bot commands."
    }
}

local function isCommandInContext(channelId, command, message) -- returns true if a command can be used in a certain channel, uses the message where -help was sent.
    for i,v in pairs(command.ChannelWhitelist) do
        if v == channelId then
            if not command.PermissionValidator then
                return true
            else
                return command.PermissionValidator(message)
            end
        end
    end
    return false
end

function makeCommands(message, contextDependent) -- makes the help message for the command list, only lists commands in a specific command context if contextDependent = true.
    local noCommands = "You cannot use any commands in this context."
    local returnString = noCommands
    local newChannelId = message.channel.id
    if message.channel.type == 1 then
        newChannelId = "-1"
    end
    for k,v in pairs(commands) do
        if (not contextDependent) or isCommandInContext(newChannelId, v, message) then
            if returnString == noCommands then
                returnString = ""
            end
            returnString = returnString .. "**".. k .. "**: " .. v.Desc .. "\n\n"
        end
    end
    return returnString
end


print("Starting VenadaBOT with token " .. args[2])

discordia.extensions()

client:on('ready', function()
    print("Logged in as " .. client.user.username)
end)

local function helpMessage(commandName, commandInfo)
    local returnTable = {
        embed = {
            title = commandName,
            description = commandInfo.Desc,
            color = 0x7CFC00-- hex color code
        }
    }
    if commandInfo.Usage then
        returnTable.embed.fields = {
            {
                name = "Usage:",
                value = commandInfo.Usage,
                inline = true
            }
        }
    end
    return returnTable
end

local function runCommand(command, message, args, prompts)
    local cmdSuc, cmdErr = coroutine.resume(coroutine.create(function()
        command.Execute(message, args, prompts)
    end))
    if cmdSuc == false then
        message.channel:send{
            embed = {
                title = "Command Error",
                description = "There was an internal error while attempting to perform this command. Robert has been messaged about this.",
                color = 0xff0000
            }
        }
        if client.owner then
            client.owner:getPrivateChannel():send("BOT ERROR: " .. cmdErr .. " message was " .. message.content .. " in " .. message.channel.id)
        end
    end
end

client:on('messageCreate', function(message)
    if prompts[message.author.id] then
        if prompts[message.author.id].Channel ~= message.channel.id then
            return
        end
        if message.content == "Cancel." then
            message.channel:send{
                embed = {
                    title = "Canceled.",
                    color = 0xFF0000
                }
            }
            prompts[message.author.id] = nil
            return
        end
        local promptsTable = prompts[message.author.id]
        print(#promptsTable.AnswerTable)
        print(#commands[promptsTable.CommandName].Prompts)
        if #promptsTable.AnswerTable + 1 >= #commands[promptsTable.CommandName].Prompts then
            table.insert(promptsTable.AnswerTable, message.content)
            message.channel:send{
                embed = {
                    title = "Prompts Completed",
                    description = "Your message has been sent. Thank you for using VenadaBOT's prompts system! <3",
                    color = 0x00ff00
                }
            }
            runCommand(commands[promptsTable.CommandName], message, nil, promptsTable.AnswerTable)
            --commands[promptsTable.CommandName].Execute(message, nil, promptsTable.AnswerTable)
            prompts[message.author.id] = nil
            return
        end
        table.insert(promptsTable.AnswerTable, message.content)
        message.channel:send{
            embed = {
                title = "Prompt",
                description = commands[promptsTable.CommandName].Prompts[#promptsTable.AnswerTable + 1]
            }
        }
    end
    if message.channel.type == 1 then
    if client:getChannel(venadaChannel.corporateCommands) and message.author.id ~= client.user.id then
        client:getChannel(venadaChannel.corporateCommands):send({
            embed = {
                title = "Direct Message from " .. message.author.tag,
                fields = {
                    {
                        name = "Message",
                        value = message.content,
                        inline = false,
                    },
                },
                footer = {
                    text = message.author.id
                }
            }
        })
    end
    end
    for key, value in pairs(commands) do
        local keyWithPrefix = string.lower(prefix .. key)
        if message.content:lower():sub(1, #keyWithPrefix) == keyWithPrefix then
            if value.ChannelWhitelist then
                local whitelisted = false
                for _,id in pairs(value.ChannelWhitelist) do
                    if id == "-1" then -- magic number used internally in the bot for a direct message
                        if message.channel.type == 1 then -- magic number used by Discord for a direct message
                            whitelisted = true
                        end
                    end
                    if id == message.channel.id  then
                        whitelisted = true
                    end
                end
                if whitelisted == false then
                    return
                end
            end
            if value.PermissionValidator then
                if value.PermissionValidator(message) == false then
                    message.channel:send({
                        embed = {
                            title = "Permission Denied",
                            description = "You don't have permission to run this command.",
                            color = 0xFF0000
                        }
                    })
                    return
                end
            end
            if value.Argmax then
                if #string.split(message.content, " ") - 1 > value.Argmax then
                    message.channel:send(helpMessage(key, value))
                    return
                end
            end
            if value.Argmin then
                if #string.split(message.content, " ") - 1 < value.Argmin then
                    message.channel:send(helpMessage(key, value))
                    return
                end
            end
            if value.Prompts then
                if not prompts[message.author.id] then
                    print("making prompts")
                   prompts[message.author.id] = {
                       Channel = message.channel.id,
                       CommandName = key,
                       AnswerTable = {

                       }
                   }
                   print("sending prompts")
                   local theEmbed = {
                        embed = {
                            title = "Prompts",
                            description = value.Prompts[1] .. "\n\nProtip: Say 'Cancel.' **(with grammar)** to exit the prompts at any time.",
                        }
                   }
                   print(debug.dumptable(theEmbed))
                   message.channel:send(theEmbed)
                   return
                end
                return
            end
            local argsTable = string.split(message.content, " ")
            table.remove(argsTable, 1) -- remove the command from args table
            runCommand(value, message, argsTable) -- run command in a sep thread with error handling.
            -- log bot commands
            client:getChannel(venadaChannel.botSpeak):send({
                embed = {
                    title = "Command from " .. message.author.tag,
                    fields = {
                        {
                            name = "Command",
                            value = message.content,
                            inline = false,
                        },
                        {
                            name = "Channel",
                            value = ternary(message.channel.type == 1, "Direct Message", message.channel.mentionString)
                        }
                    },
                    footer = {
                        text = message.author.id
                    },
                    thumbnail = {
                        url = "http://icons.iconarchive.com/icons/artua/mac/512/Terminal-icon.png"
                    }
                }
            })
        end
    end
end)

client:run('Bot ' .. args[2])
coroutine.resume(coroutine.create(function() -- go through the status rotations
    while true do
        for _,status in pairs(statusRotations) do
            client:setGame(helpStatus .. status)
            require('timer').sleep(statusRotationDelay * 1000)
        end
    end
end))