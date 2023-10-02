document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll('#content div#players').forEach(div => {
        Common.scroll_table_multi([ div ], {
            'a.data.server_id': href => {
                fetch(`/json/server/${href}`).then(r => r.json()).then(data => div.querySelectorAll('.f_server_name').forEach(el => {
                    el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.name)));
                }));
                return (offset, limit) => `/json/server/${href}/players/${offset}/${limit}`;
            },
            'a.data.map_id': href => {
                fetch(`/json/map/${href}`).then(r => r.json()).then(data => div.querySelectorAll('.f_map_name').forEach(el => {
                    el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.displayname)));
                }));
                return (offset, limit) => `/json/map/${href}/players/${offset}/${limit}`;
            }
        }, data => data.players, (template, data, index) => {
            let player = data.player;
            let entry = template.cloneNode(true);
            const fields = {
                '.f_index'          : el => Common.createEl('SPAN', {}, "number", 1 + index),
                '.f_rank'           : el => Common.rating(data.glicko2),
                '.f_name'           : el => Common.createEl('SPAN', {}, "name text", Common.createEl('A', { href: `/player/${player.id}` }, [], Common.format_text(player.displayname))),
                '.f_total_games'    : el => Common.createEl('SPAN', {}, "number", player.total_games),
                '.f_total_playtime' : el => Common.createEl('SPAN', {}, "number", Common.format_duration_minutes(player.total_time)),
                '.f_kills'          : el => Common.bar({
                    value: player.total_kills,
                    total: Common.sum([player.total_kills,player.total_deaths,player.total_bdeaths]),
                    prefix: Common.createEl('SPAN', {}, "smiley left", " "),
                    suffix: Common.createEl('SPAN', {}, "smiley right", " "),
                    fill_color: 'rgba(100,63,51,0.66)',
                    empty_color: 'rgba(0,0,0,0.15)'
                }),
                '.f_kills_count'    : el => Common.createEl('SPAN', {}, "number", player.total_kills),
                '.f_deaths_count'   : el => Common.createEl('SPAN', {}, "number", Common.sum([ player.total_deaths , player.total_bdeaths ])),
                '.f_assists'        : el => Common.createEl('SPAN', {}, "number", player.total_assists),
                '.f_buildings'      : el => Common.bar({
                    value: player.total_built,
                    total: Common.sum([player.total_built,player.total_bkills]),
                    prefix: Common.createEl('SPAN', {}, "smiley smiley_ckit left"),
                    suffix: Common.createEl('SPAN', {}, "smiley smiley_lcannon right"),
                    fill_color: 'rgba(100,100,63,0.66)',
                    empty_color: 'rgba(100,63,51,0.66)'
                }),
                '.f_building_kd'    : el => Common.createEl('SPAN', {}, "number", player.total_deaths > 0 ? (player.total_bkills / player.total_deaths).toFixed(2) : "N/A"),
                '.f_build_count'    : el => Common.createEl('SPAN', {}, "number", player.total_built),
                '.f_bkills_count'   : el => Common.createEl('SPAN', {}, "number", player.total_bkills),
                '.f_team_preference': el => Common.bar({
                    value: player.total_time_h,
                    total: player.total_time,
                    prefix: Common.createEl('SPAN', {}, "smiley smiley_bsuit left"),
                    suffix: Common.createEl('SPAN', {}, "smiley smiley_tyrant right"),
                    fill_color: 'rgba(51,63,100,0.66)',
                    empty_color: 'rgba(63,100,51,0.66)'
                }),
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
