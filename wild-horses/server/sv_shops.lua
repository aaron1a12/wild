RegisterNetEvent('wild:sv_playAmbSpeech', function(pedNet, line)
    TriggerClientEvent('wild:cl_onPlayAmbSpeech', -1, pedNet, line)
end)
