--[[
local audio = audio_stream_load("passive-noise.ogg")
audio_stream_set_looping(audio, true)
audio_stream_play(audio, true, 0)
log_to_console(tostring(audio_stream_get_frequency(audio)))

local soundDistPrev = nil
local soundDistMax = 10000
local function update()
    local np = gNetworkPlayers[0]
    local l = gLakituState
    local soundDist = nil
    local soundSourceSpeed = 0
    for i = 1, MAX_PLAYERS - 1 do
        local t = gMarioStates[i]
        local tnp = gNetworkPlayers[i]
        if tnp.currAreaSyncValid and np.currLevelNum == tnp.currLevelNum and np.currActNum == tnp.currActNum and np.currAreaIndex == tnp.currAreaIndex then
            local newSoundDist = math.sqrt((l.pos.x - t.pos.x)^2 + (l.pos.y - t.pos.y)^2 + (l.pos.z - t.pos.z)^2)
            if not soundDist or newSoundDist < soundDist then
                soundDist = newSoundDist
                soundSourceSpeed = math.sqrt(t.vel.x^2 + t.vel.y^2 + t.vel.z^2)
            end
        end
    end
    if soundDist and soundDistPrev then
        audio_stream_set_volume(audio, math.abs(math.min(soundDist-soundDistMax, 0))/soundDistMax * soundSourceSpeed/150)
        local soundDistSpeed = soundDist - soundDistPrev
        audio_stream_set_frequency(audio, 1 - (soundDistSpeed/150)*0.2)
    else
        audio_stream_set_volume(audio, 0)
    end

    soundDistPrev = soundDist
end

hook_event(HOOK_UPDATE, update)
]]