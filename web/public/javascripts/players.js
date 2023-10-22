document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll('#content div#players').forEach(div => {
        Common.scroll_table_multi([ div ], {
            'a.data.server_id': href => {
                fetch(`/json/server/${href}`).then(r => r.json()).then(data => div.querySelectorAll('.f_server_name').forEach(el => {
                    el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.name)));
                }));
                const playerName = document.querySelector('a.data.player_name');
                if (playerName && playerName.getAttribute("href")) {
                    return (offset, limit) => `/json/server/${href}/players/name=${playerName.getAttribute("href")}`;
                } else {
                    return (offset, limit) => `/json/server/${href}/players/${offset}/${limit}`;
                }
            },
            'a.data.map_id': href => {
                fetch(`/json/map/${href}`).then(r => r.json()).then(data => div.querySelectorAll('.f_map_name').forEach(el => {
                    el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.displayname)));
                }));
                return (offset, limit) => `/json/map/${href}/players/${offset}/${limit}`;
            }
        }, data => data.players, (template, data, index) => {
            const player = data.player;
            const entry = template.cloneNode(true);
            const fields = {
                '.f_index'          : el => Common.createEl('SPAN', {}, "number", 1 + index),
                '.f_rank'           : el => Common.createEl('SPAN', {}, "rating", Common.deferEl(el => Common.rating(data.glicko2, [ el.offsetWidth, el.offsetHeight ]))),
                '.f_name'           : el => Common.createEl('SPAN', {}, "name text", Common.createEl('A', { href: `/player/${player.id}` }, [], Common.format_text(player.displayname))),
                '.f_total_games'    : el => Common.createEl('SPAN', {}, "number", player.total_games),
                '.f_total_playtime' : el => Common.createEl('SPAN', {}, "number", Common.format_duration_minutes(player.total_time)),
                '.f_kills'          : el => Common.createEl('SPAN', {}, "bar2", Common.fillBar(Common.regions([
                    { value: player.total_kills  , color: Common.color("player_kills")   , title: Common.formatText("[bsuit][tyrant]") },
                    { value: player.total_bdeaths, color: Common.color("building_deaths"), title: Common.formatText("[reactor][overmind]") },
                    { value: player.total_deaths , color: Common.color("player_deaths")  , title: Common.formatText("[bsuit][tyrant]") },
                ]))),
                '.f_kills_count'    : el => Common.createEl('SPAN', {}, "number", player.total_kills),
                '.f_deaths_count'   : el => Common.createEl('SPAN', {}, "number", Common.sum([ player.total_deaths , player.total_bdeaths ])),
                '.f_assists'        : el => Common.createEl('SPAN', {}, "number", player.total_assists),
                '.f_buildings'      : el => Common.createEl('SPAN', {}, "bar2", Common.fillBar(Common.regions([
                    { value: player.total_built , color: Common.color('building_builds'), title: Common.formatText("[ckit]") },
                    { value: player.total_bkills, color: Common.color('building_kills') , title: Common.formatText("[lcannon]") },
                ]))),
                '.f_building_kd'    : el => Common.createEl('SPAN', {}, "number", player.total_deaths > 0 ? (player.total_bkills / player.total_deaths).toFixed(2) : "N/A"),
                '.f_build_count'    : el => Common.createEl('SPAN', {}, "number", player.total_built),
                '.f_bkills_count'   : el => Common.createEl('SPAN', {}, "number", player.total_bkills),
                '.f_team_preference': el => Common.createEl('SPAN', {}, "bar2", Common.fillBar(Common.regions([
                    { value: player.total_time_h, color: Common.color('team_human'), title: Common.formatText("[bsuit]") },
                    { value: player.total_time_a, color: Common.color('team_alien'), title: Common.formatText("[tyrant]") },
                ]))),
                '.f_total_time_h'   : el => Common.createEl('SPAN', {}, "number", Common.format_duration_hm(player.total_time_h)),
                '.f_total_time_a'   : el => Common.createEl('SPAN', {}, "number", Common.format_duration_hm(player.total_time_a))
            };
            Object.entries(fields).forEach(async ([ selector, fn ]) => entry.querySelectorAll(selector).forEach(el => {
                const newEl = fn(el);
                el.classList.forEach(cname => {
                    if (`.${cname}` !== selector) {
                        newEl.classList.add(cname)
                    }
                });
                el.replaceWith(newEl);
            }));
            // entry.find('.f_reliability').html(Common.percent(player.total_rqs,player.total_sessions));
            return entry;
        });
    });
});
