RegisterNetEvent('wild:shops:sv_playAmbSpeech', function(pedNet, line)
    TriggerClientEvent('wild:shops:cl_onPlayAmbSpeech', -1, pedNet, line)
end)
