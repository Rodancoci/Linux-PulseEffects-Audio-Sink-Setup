#!/bin/bash

# Get the index of the default source
mic_index=$(pacmd list-sources | grep "\* index:" | grep -o "[0-9]*")

# This gets the sink-input ID from the loopbacks that should go to streamsink.
# For some reason, when PulseEffects is running, the loopback module ignores the sink parameter
# and defaults to 'PulseEffects (apps)'.
# The ID returned by this function is what we'll need to manually remap to streamsink.
find_sink () {
	local module_id=$1
	local sink_input_id=$(grep -Po "Sink Input #[0-9]+ Owner Module: $module_id" <<< $id_search | grep -Po '#[0-9]+' | tr -d '#')
	echo $sink_input_id
}

# Create the Game and Stream sinks and the following loopbacks:
# Game Sink monitor				--> PulseEffects (apps)
# Game Sink monitor				--> Stream Sink
# Currently selected microphone	--> Stream Sink
# The last two default to PulseEffects anyway and have to be manually moved later.
pactl load-module module-null-sink sink_name=gamesink sink_properties="device.description='Game\ Sink'"
pactl load-module module-null-sink sink_name=streamsink sink_properties="device.description='Stream\ Sink'"
pactl load-module module-loopback source=gamesink.monitor sink=PulseEffects_apps latency_msec=1
module_1=$(pactl load-module module-loopback source=$mic_index sink=streamsink latency_msec=1)
module_2=$(pactl load-module module-loopback source=gamesink.monitor sink=streamsink latency_msec=1)
printf "$module_1\n"
printf "$module_2\n"

# Produces a string with the sink-input IDs and their respective module IDs
id_search=$(pactl list sink-inputs | grep -e "Sink Input #" -e "Owner Module: " | tr -d "\t" | tr "\n" " ")

# Get the sink-input IDs from the module IDs and remap them to the Stream Sink
id_1=$(find_sink $module_1)
id_2=$(find_sink $module_2)

pacmd move-sink-input $id_1 streamsink
pacmd move-sink-input $id_2 streamsink
