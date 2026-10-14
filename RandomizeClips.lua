-- Script DaVinci Resolve - Duplicate & Audio-Safe Timeline Shuffle (n Clips)
local resolve = app:GetResolve()
local project = resolve:GetProjectManager():GetCurrentProject()
local mediaPool = project:GetMediaPool()

local TARGET_NAME = "CHANGE_HERE" --CHANGE THIS FOR DESIRED TIMELINE
local timeline = nil
local count = project:GetTimelineCount()

-- Find your current 'TARGET_NAME' timeline
for i = 1, count do
    local tl = project:GetTimelineByIndex(i)
    if tl:GetName() == TARGET_NAME then
        timeline = tl
        break
    end
end

if not timeline then
    print("❌ Error: Could not find timeline named '" .. TARGET_NAME .. "'")
    return
end

-- Grab all video items from Track 1
local TRACK_INDEX = 1
local videoItems = timeline:GetItemListInTrack("video", TRACK_INDEX)
if not videoItems or #videoItems == 0 then
    print("❌ No clips found on Track " .. TRACK_INDEX)
    return
end

print(string.format("🎯 Found %d clips on '%s'. Processing...", #videoItems, TARGET_NAME))

-- Collect source media and exact trim ranges
local clipInfoList = {}
for _, item in ipairs(videoItems) do
    local mediaPoolItem = item:GetMediaPoolItem()
    if mediaPoolItem then
        table.insert(clipInfoList, {
            mediaPoolItem = mediaPoolItem,
            startFrame = item:GetSourceStartFrame(),
            endFrame = item:GetSourceEndFrame()
        })
    end
end

-- Fisher-Yates shuffle algorithm
function shuffle_table(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

math.randomseed(os.time())
clipInfoList = shuffle_table(clipInfoList)

-- Create a fresh timeline to build the shuffled sequence
local tempName = TARGET_NAME .. "_Temp_" .. math.random(1000, 9999)
local newTimeline = mediaPool:CreateEmptyTimeline(tempName)

if not newTimeline then
    print("❌ Error: Failed to create temporary timeline.")
    return
end

-- Set the new timeline as current so appends target it correctly
project:SetCurrentTimeline(newTimeline)

-- Append each item individually (omitting mediaType includes both video & audio)
local successCount = 0
for _, clipInfo in ipairs(clipInfoList) do
    local clipDesc = {
        mediaPoolItem = clipInfo.mediaPoolItem,
        startFrame = clipInfo.startFrame,
        endFrame = clipInfo.endFrame
    }
    
    local appended = mediaPool:AppendToTimeline({clipDesc})
    if appended then
        successCount = successCount + 1
    end
end

-- Clean up the old timeline and rename the new one to 'TARGET_NAME'
mediaPool:DeleteTimelines({timeline})
newTimeline:SetName(TARGET_NAME)

print(string.format("=== Success! All %d clips (with duplicates & audio) are fully shuffled! ===", successCount))
