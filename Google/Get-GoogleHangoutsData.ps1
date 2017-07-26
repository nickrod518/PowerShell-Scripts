
$HangoutsFilePath = '~\downloads\hangouts.json'
$HangoutsRaw = Get-Content $HangoutsFilePath
$HangoutsData = Get-Content $HangoutsFilePath | ConvertFrom-Json

$Conversations = @()
$AllParticipants = @()

function Process-GoogleHangoutsData {
    # First we want to get all participants, so we loop fully once
    foreach ($Key in $HangoutsData.conversation_state) {
        $Conversation = $HangoutsData.conversation_state.$Key.'conversation_state'.'conversation'

        # Get all participants
        foreach ($PersonData in $Conversation.'participant_data') {
            $Person  = $Conversation.'participant_data'.$PersonData
            $Gaia_id = $Person.'id'.'gaia_id'
            if (-not $person.'fallback_name' -or $Person.'fallback_name' -eq $null) { break }
            if (-not $AllParticipants.$Gaia_id) {
                $AllParticipants.$gaia_id = $Person.'fallback_name'
            }
        }
    }
    foreach ($Key in $HangoutsData.'conversation_state') {
        $conversation_state = $HangoutsData.'conversation_state'.$key
        $id = $conversation_state.'conversation_id'.'id'
        $conversation = $conversation_state.'conversation_state'.'conversation'

        # Find participants
        $participants = @()
        $participants_obj = @{}
        foreach ($person_key in $conversation.'participant_data') {
            $person  = $conversation.'participant_data'.$person_key
            $gaia_id = $person.'id'.'gaia_id'
            $name = 'Unknown'
            if ($person.'fallback_name') {
                $name = $person.'fallback_name'
            } else {
                $name = $AllParticipants.$gaia_id
            }
            $participants.push($name)
            $participants_obj.$gaia_id = $name
        }
        $participants_string = $participants.join(", ")
        # Add to list
        #$(".convo-list").append("<a href=\"javascript:void(0)\" onclick=\"switchConvo('"+id+"')\" class=\"list-group-item\">" + participants_string + "</a>")
        # Parse events
        $events = @()
        for (event_key in conversation_state.'conversation_state'.'event'){
            $convo_event = conversation_state.'conversation_state'.'event'.event_key
            $timestamp = convo_event.'timestamp'
            $msgtime = formatTimestamp(timestamp)
            $sender = convo_event.'sender_id'.'gaia_id'
            $message = ""
            if(convo_event.'chat_message'){
                # Get message
                for(msg_key in convo_event.'chat_message'.'message_content'.'segment'){
                    $segment = convo_event.'chat_message'.'message_content'.'segment'.msg_key
                    if(segment.'type' == 'LINE_BREAK') $message += "\n"
                    if(!segment.'text') continue
                    message += twemoji.parse(segment.'text')
                }
                # Check for images on event
                if(convo_event.'chat_message'.'message_content'.'attachment'){
                    foreach ($attach_key in convo_event.'chat_message'.'message_content'.'attachment'){
                        $attachment = convo_event.'chat_message'.'message_content'.'attachment'.attach_key
                        console.log(attachment)
                        if(attachment.'embed_item'.'type'.0 == "PLUS_PHOTO"){
                            message += "\n<a target='blank' href='" + attachment.'embed_item'.'embeds.PlusPhoto.plus_photo'.'url' + "'><img class='thumb' src='" + attachment.'embed_item'.'embeds.PlusPhoto.plus_photo'.'thumbnail'.'image_url' + "' /></a>"
                        }
                    }
                }
                events.push({msgtime: msgtime, sender: participants_obj.sender, message: message, timestamp: timestamp})
            }
        }
        <# Sort events by timestamp
        $events.sort(function($a, $b){
            $keyA = $a.timestamp,
                $keyB = $b.timestamp
            if($keyA < $keyB) return -1
            if($keyA > $keyB) return 1
            return 0
        })#>
        # Add events
        $Conversations.$id = $events
    }
}

function switchConvo($id) {
    $('.txt').text('')
    foreach ($event_id in Conversations.id){
        $convo_event = Conversations.id.event_id
        $('.txt').append($convo_event.msgtime + ": " + $convo_event.sender + ": " + $convo_event.message + "\n")
    }
}

function zeroPad($string) {
    return ($string < 10) ? "0" + $string : $string
}

function formatTimestamp($timestamp) {
    $d = new Date($timestamp/1000)
    $formattedDate = $d.getFullYear() + "-" +
        zeroPad($d.getMonth() + 1) + "-" +
        zeroPad($d.getDate())
    $hours = zeroPad($d.getHours())
    $minutes = zeroPad($d.getMinutes())
    $formattedTime = $hours + ":" + $minutes
    return $formattedDate + " " + $formattedTime
}