# Currently used messages

The following messages are used for both Tremulous and Unvanquished


## Syntax

	<field>      - A named field, <, > not included in the message
	<simplename> - Player name with no formatting/color/etc... symbols
	<time>       - \d+:\d+


## Messages

	<time> InitGame: \<data fields separated by \>
	<time> ShutdownGame:

	<time> RealTime: <year>/<month>/<day> <hour>:<minute>:<second>
	<time> RealTime: <year>-<month>-<day> <hour>:<minute>:<second>
	<time> RealTime: <year>/<month>/<day> <hour>:<minute>:<second> <time_zone>
	<time> RealTime: <year>-<month>-<day> <hour>:<minute>:<second> <time_zone>

	<time> Beginning Sudden Death
	<time> Beginning Weak Sudden Death

	<time> ClientConnect <slot> [<ip>] (<guid>) "<simplename>" "<name>"
	<time> ClientConnect <slot> [<ip>] (<guid>) "<simplename>" "<name>" <flags>

	<time> ClientDisconnect <slot> [<ip>] (<guid>) "<simplename>"

	<time> AdminAuth: <slot> "<simplename>" "<authname>" [<level>] (<guid>)

	<time> Die: <killerslot> <killedslot> <mod> <assistslot> <assistteam>: <killername> killed <killedname>
	<time> Die: <killerslot> <killedslot> <mod>: <killername> killed <killedname>

	<time> Kill: <killerslot> <killedslot> <modnumber>: <killername> <killedname> by <mod>

	<time> Construct: <slot> <entityid> <buildingname>: <ignored>
	<time> Construct: <slot> <entityid> <buildingname> <replacedids>: <ignored>

	<time> Deconstruct: <slot> <entityid> <buildingname> <mod>: <ignored>

	<time> Exit: <reason>

	<time> score: <score> ping: <ping> client: <slot> <name>

	<time> ClientTeamClass: <slot> <team> <weapon>

	<time> ClientRename: <slot> [<ip>] (<guid>) "<name>" -> "<newname>" "<newnameformatted>"

	<time> Stage: <team> <stage>: <message>

	<time> CombatSettings: <weapons>

	<time> CombatStats: <slot> <data>
	
	
## In regexp form

	/^\s*(?<time>\d+:\d+)\s*InitGame:\s+\\(?<rawdata>.+)\s*$/
	/^\s*(?<time>\d+:\d+)\s*ShutdownGame:\s*$/

	/^\s*(?:\d+:\d+)\s*RealTime:\s+(?<year>\d{4})[\/-](?<month>\d{2})[\/-](?<day>\d{2})\s+(?<hour>\d{2}):(?<minute>\d{2}):(?<second>\d{2})(?:(\s+(?<time_zone>[A-Z]+)))?\s*$/

	/^\s*(?<time>\d+:\d+)\s*Beginning\s*Sudden\s*Death\s*$/
	/^\s*(?<time>\d+:\d+)\s*Beginning\s*Weak\s*Sudden\s*Death\s*$/

	/^\s*(?<time>\d+:\d+)\s*ClientConnect:\s+(?<slot>\d+)\s+\[(?<ip>\S+?)\]\s+\((?<guid>\S+?)\)(?:\s+\"(?<simplename>.+?)\")?\s+\"(?<name>.+?)\"(?:\s+(?<flags>\S+))?\s*$/

	/^\s*(?<time>\d+:\d+)\s*ClientDisconnect:\s*(?<slot>\d+)\s+\[(?<ip>\S*?)\]\s+\((?<guid>\S+?)\)\s+\"(?<simplename>.+?)\"\s*$/

	/^\s*(?<time>\d+:\d+)\s*AdminAuth:\s+(?<slot>\d+)\s+\"(?<simplename>.+?)\"\s+\"(?<authname>.+?)\"\s+\[(?<level>\-?\d+)\]\s+\((?<guid>\S+?)\):\s+.+$/

	/^\s*(?<time>\d+:\d+)\s*Die:\s+(?<killerslot>\d+)\s+(?<killedslot>\d+)\s+(?<mod>\S+)(?:\s+(?<assistslot>\d+)\s+(?<assistteam>\d+))?:\s+(?<killername>.+?)\s+killed\s+(?<killedname>.+)$/

	/^\s*(?<time>\d+:\d+)\s*Kill:\s+(?<killerslot>\d+)\s+(?<killedslot>\d+)\s+(?<modnumber>\S+):\s+(?<killername>.+?)\s+killed\s+(?<killedname>.+?)\s+by\s+(?<mod>\S+)$/

	/^\s*(?<time>\d+:\d+)\s*Construct:\s+(?<slot>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+):\s+.+$/
	/^\s*(?<time>\d+:\d+)\s*Construct:\s+(?<slot>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+)\s+(?<replacedids>\d+(?:\s+\d+)*?):\s+.+$/

	/^\s*(?<time>\d+:\d+)\s*Deconstruct:\s+(?<playerid>\d+)\s+(?<entityid>\d+)\s+(?<buildingname>\S+)\s+(?<mod>\S+):\s+.+$/

	/^\s*(?<time>\d+:\d+)\s*Exit:\s+(?<reason>.+)\s*$/

	/^\s*(?<time>\d+:\d+)\s*score:\s+(?<score>\-?\d+)\s+ping:\s+(?<ping>\d+)\s+client:\s+(?<slot>\d+)\s+(?<name>.+?)\s*$/

	/^\s*(?<time>\d+:\d+)\s*ClientTeamClass:\s+(?<slot>\d+)\s+(?<team>\S+)\s+(?<weapon>\S+)\s*$/

	/^\s*(?<time>\d+:\d+)\s*ClientRename:\s+(?<slot>\d+)\s+\[(?<ip>\S+)?\]\s+\((?<guid>(\S+)?)\)\s+\"(?<name>.+?)\"\s+->\s+\"(?<newname>.+?)\"\s+\"(?<newnameformatted>.+?)\"\s*$/

	/^\s*(?<time>\d+:\d+)\s*Stage:\s+(?<team>[A|H])\s+(?<stage>\d+):\s+(?<message>.+?)\s*$/

	/^\s*(?<time>\d+:\d+)\s*CombatSettings:\s+(?<weapons>.+?)\s*$/

	/^\s*(?<time>\d+:\d+)\s*CombatStats:\s+(?<slot>\d+)\s+(?<data>.+?)\s*$/


# Planned but not yet fully implemented

## Clans support

Currently not used.

Will require client support for registering/adding/removing members of clan
as well as for providing the ClanAuth message when a clan member joins.

	<time> ClanAdd: [<tag>] (<guid>) <isleader> <name>
	<time> ClanRemove: [<tag>] (<guid>) <isleader> <name>
	<time> ClanResign: [<tag>] (<guid>) <isleader> <name>
	<time> ClanAuth: [<tag>] (<guid>) <isleader> <name>
				
	/^\s*(?<time>\d+:\d+)\s*Clan(?<type>Add|Remove|Resign|Auth):\s+\[(?<tag>.+?)\]\s+(?<guid>\S+)\s+(?<isleader>[01])\s+(?<name>.+)\s*$/


## Currently not used

The contents of following messages is ignored but some of them might be used for
tracking player activity in the future.

	<time> --------------------------------
	<time> Warmup: <duration>
	<time> ClientBegin: <slot>
	<time> AdminExec: <ignored>
	<time> Say: <slot> "<name>": "<message>"
	<time> SayTeam: <slot> "<name>": "<message>"
	<time> SayArea: <slot> "<name>": "<message>"
	<time> CallVote: <slot> "<name>": <vote>
	<time> CallTeamVote: <slot> "<name>": <vote>
	<time> EndVote: <ignored>
	<time> Msg: <ignored>
	<time> PrivMsg: <ignored>
	<time> AdminMsg: <ignored>
	<time> MsgPublic: <ignored>
	<time> PrivMsgPublic: <ignored>
	<time> AdminMsgPublic: <ignored>
	<time> revert: <operation> <entityid> <name>
	<time> Inactivity: <slot>


	/^\s*(?<time>\d+:\d+)\s*-+\s*$/
	/^\s*(?<time>\d+:\d+)\s*Warmup:\s+(?<duration>\d+)\s*$/
	/^\s*(?<time>\d+:\d+)\s*ClientBegin:\s+(?<slot>\d+)\s*$/
	/^\s*(?<time>\d+:\d+)\s*AdminExec:.*$/
	/^\s*(?<time>\d+:\d+)\s*Say(?:Team|Area)?:\s+(?<slot>\-?\d+)\s+\"(?<name>.+?)\":\s+(?<message>.*?)\s*$/
	/^\s*(?<time>\d+:\d+)\s*Call(?:Team)?Vote:\s+(?<slot>\d+)\s+\"(?<name>.+?)\":\s+(?<vote>.+?)\s*$/
	/^\s*(?<time>\d+:\d+)\s*EndVote:\s+.+$/
	/^\s*(?<time>\d+:\d+)\s*(?:Priv|Admin)Msg(?:Public)?:\s+.+$/
	/^\s*(?<time>\d+:\d+)\s*revert:\s+(?<operation>restore|remove)\s+(?<entityid>\d+)\s+(?<name>.+?)\s*$/
	/^\s*(?<time>\d+:\d+)\s*Inactivity:\s*(?<slot>\d+)\s*$/

