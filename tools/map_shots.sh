#!/usr/bin/env bash
# Top-down, gameplay and town close-up screenshots of every skirmish and campaign map. Usage: tools/map_shots.sh <out-dir> [godot]
set -u
OUT="${1:?out dir}"
GODOT="${2:-${GODOT:-godot}}"
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
shot() {
	"$GODOT" --path . --resolution 1280x720 -s res://tools/map_shot.gd -- --out "$OUT/$1" "${@:2}" 2>&1 | grep "^saved" || echo "failed $1"
}
shot skirmish-burma-road --scene res://game/burma_road.tscn --town 13,22
shot skirmish-ten-degree-atolls --scene res://game/ten_degree_atolls.tscn --town 2,33
shot skirmish-mekong-delta --scene res://game/mekong_delta.tscn --town 31,5
shot skirmish-chiang-rai --scene res://game/chiang_rai.tscn --town 6,27
shot skirmish-golden-confluence --scene res://game/showcase.tscn
shot campaign-phillips-channel --scene res://game/phillips_channel.tscn --town 49,14
shot campaign-sop-ruak --scene res://game/sop_ruak.tscn --town 26,8
shot campaign-kokang --scene res://game/mission_kokang.tscn --mission kokang --town 24,8
shot campaign-tachileik --scene res://game/campaign_mission.tscn --mission tachileik --town 31,11
shot campaign-operation-1027 --scene res://game/campaign_mission.tscn --mission operation_1027 --town 31,11
shot campaign-black-haze --scene res://game/campaign_mission.tscn --mission black_haze --town 31,11
shot campaign-kilometer-watch --scene res://game/campaign_mission.tscn --mission kilometer_watch --town 31,11
shot campaign-shattered-monsoon --scene res://game/campaign_mission.tscn --mission shattered_monsoon --town 31,11
shot campaign-ghosts-of-patani --scene res://game/campaign_mission.tscn --mission ghosts_of_patani --town 31,11
