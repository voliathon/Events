_addon.name = 'Events'
_addon.author = 'Voliathon'
_addon.version = '1.0.1'
_addon.commands = {'events', 'campaign'}

local texts = require('texts')
local https = require('ssl.https') 

-- 1. Setup the GUI Box
local gui_settings = {
    pos = { x = 300, y = 200 },
    bg = { alpha = 200, red = 0, green = 0, blue = 0, visible = true },
    flags = { draggable = true },
    text = {
        size = 11, font = 'Consolas', alpha = 255, red = 240, green = 240, blue = 240,
        stroke = { width = 2, alpha = 255, red = 0, green = 0, blue = 0 }
    },
    padding = 10
}

local campaign_box = texts.new(gui_settings)
local is_visible = false
local current_display_text = "No data fetched yet. Type //events show first."

-- Helper function to convert BG-Wiki date strings to Lua timestamps
local function parse_date(date_str, default_year)
    local clean_str = date_str:gsub("%a+,%s+", "")
    
    local month_str, day, year = clean_str:match("(%a+)%s+(%d+),%s+(%d+)")
    if not year then
        month_str, day = clean_str:match("(%a+)%s+(%d+)")
        year = default_year
    end

    local hour, min, ampm = clean_str:match("at%s+(%d+):(%d+)%s+([ap]%.m%.)")
    
    if not month_str or not day then return 0, default_year end

    local months = {
        jan=1, feb=2, mar=3, apr=4, may=5, jun=6, jul=7, aug=8, sep=9, oct=10, nov=11, dec=12,
        january=1, february=2, march=3, april=4, june=6, july=7, august=8, september=9, october=10, november=11, december=12
    }

    local m = months[month_str:lower()] or 1
    local d = tonumber(day) or 1
    local y = tonumber(year) or default_year
    local h = tonumber(hour) or 0
    local min_val = tonumber(min) or 0

    if ampm then
        if ampm:lower() == "p.m." and h < 12 then h = h + 12 end
        if ampm:lower() == "a.m." and h == 12 then h = 0 end
    end

    return os.time({year=y, month=m, day=d, hour=h, min=min_val}), y
end

-- 2. Function to fetch and parse the data
local function fetch_campaign_data()
    local url = "https://www.bg-wiki.com/api.php?action=parse&page=Category:Adventurer_Campaigns&prop=wikitext&format=xml"
    
    local res, code = https.request(url)
    
    if code ~= 200 or not res then
        current_display_text = " Error: Could not connect to BG-Wiki. "
        campaign_box:text(current_display_text)
        return
    end

    local wikitext = res:match("<wikitext[^>]*>(.-)</wikitext>")
    if not wikitext then
        current_display_text = " Error: Could not parse BG-Wiki response. "
        campaign_box:text(current_display_text)
        return
    end

    wikitext = wikitext:gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"'):gsub("&amp;", "&")

    local phases = {}
    local current_phase = nil
    local current_year = tonumber(os.date("%Y"))
    local capture_mode = false
    
    for line in wikitext:gmatch("[^\r\n]+") do
        if line:match("202%d") or line:match("Start:") then capture_mode = true end

        if capture_mode then
            local clean_line = line:gsub("%[%[", ""):gsub("%]%]", ""):gsub("'", ""):gsub("<[^>]+>", ""):gsub("&nbsp;", " ")
            
            if clean_line:match("Phase %d") or (clean_line:match("202%d") and clean_line:match("=")) then
                local phase_name = clean_line:gsub("=", ""):match("^%s*(.-)%s*$")
                
                -- NEW FIX: Extract just the "Month Year - Phase X" part, ignoring the hidden CSS formatting
                local extracted_name = phase_name:match("(%a+%s+202%d.-Phase%s*%d+)")
                if extracted_name then
                    phase_name = extracted_name
                else
                    -- Fallback cleanup just in case
                    phase_name = phase_name:gsub("{{!}}.-{{!}}%s*", "")
                end

                if phase_name and phase_name ~= "" then
                    if current_phase then table.insert(phases, current_phase) end
                    current_phase = { name = phase_name, items = {} }
                end
            
            elseif current_phase then
                if clean_line:match("^Start:") then
                    current_phase.start_str = clean_line:match("^%s*(.-)%s*$")
                    current_phase.start_time, current_year = parse_date(clean_line, current_year)
                    
                elseif clean_line:match("^End:") then
                    current_phase.end_str = clean_line:match("^%s*(.-)%s*$")
                    current_phase.end_time = parse_date(clean_line, current_year)
                    
                elseif clean_line:match("^%s*%*") then
                    local item = clean_line:gsub("^%s*%*", ""):match("^%s*(.-)%s*$")
                    if item ~= "" then
                        table.insert(current_phase.items, item)
                    end
                end
            end
        end
    end
    if current_phase then table.insert(phases, current_phase) end

    local now = os.time()
    local active_phase = nil

    for _, phase in ipairs(phases) do
        if phase.start_time and phase.end_time then
            if now >= phase.start_time and now <= phase.end_time then
                active_phase = phase
                break
            end
        end
    end

    -- Build the UI Output
    if active_phase then
        local formatted_text = " \\cs(100,200,255)=== Active Campaign ===\\cr\n\n"
        formatted_text = formatted_text .. " \\cs(255,255,0)" .. active_phase.name .. "\\cr\n"
        formatted_text = formatted_text .. "  \\cs(200,200,200)" .. active_phase.start_str .. "\\cr\n"
        formatted_text = formatted_text .. "  \\cs(200,200,200)" .. active_phase.end_str .. "\\cr\n\n"
        
        for _, item in ipairs(active_phase.items) do
            formatted_text = formatted_text .. "  • " .. item .. "\n"
        end
        current_display_text = formatted_text
    else
        current_display_text = " No campaigns are currently active at this time. "
    end

    campaign_box:text(current_display_text)
end

-- 3. Command handler
windower.register_event('addon command', function(...)
    local args = {...}
    local command = args[1] and args[1]:lower() or 'help'

    if command == 'help' then
        windower.add_to_chat(207, '--- ' .. _addon.name .. ' v' .. _addon.version .. ' ---')
        windower.add_to_chat(207, 'Commands: //events or //campaign')
        windower.add_to_chat(207, '  show     - Displays the GUI and fetches current campaigns.')
        windower.add_to_chat(207, '  hide     - Hides the GUI.')
        windower.add_to_chat(207, '  export   - Saves the current GUI text to export.txt in the addon folder.')

    elseif command == 'show' then
        is_visible = true
        current_display_text = " Fetching current campaigns from BG-Wiki... "
        campaign_box:text(current_display_text)
        campaign_box:show() 

        coroutine.schedule(function() fetch_campaign_data() end, 0.1)

    elseif command == 'hide' then
        is_visible = false
        campaign_box:hide()

    elseif command == 'export' then
        local file = io.open(windower.addon_path .. 'export.txt', 'w')
        if file then
            file:write(current_display_text)
            file:close()
            windower.add_to_chat(207, 'GameEvents: Output exported to export.txt in the addon folder.')
        else
            windower.add_to_chat(167, 'GameEvents: Error saving export.txt. Check folder permissions.')
        end
        
    else
        windower.add_to_chat(167, 'Unknown GameEvents command. Type "//events" for a list of valid commands.')
    end
end)

windower.register_event('unload', function()
    if campaign_box then campaign_box:destroy() end
end)
