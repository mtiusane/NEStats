document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll("#content div#player").forEach(async div => {
        const link = div.querySelector('a.data.player_id');
        if (link) {
            const player_id = link.getAttribute('href');
            link.remove();
            fetch(`/json/player/${player_id}`).then(r => r.json()).then(data => {
                Common.load_fields_generic('#content .player_totals', data).then(targets => {                  
                    Common.scroll_table_generic('#content div#player_deaths', (offset, limit) => `/json/player/${player_id}/deaths_by_weapon/${offset}/${limit}`, data => data.deaths);
                    Common.scroll_table_generic('#content div#player_kills', (offset, limit) => `/json/player/${player_id}/kills_by_weapon/${offset}/${limit}`, data => data.kills);
                
                    Common.scroll_table_generic('#content div#player_maps', (offset, limit) => `/json/player/${player_id}/favorite_maps/${offset}/${limit}`, data => data.maps);
                    Common.scroll_table_generic('#content div#player_top_kills', (offset, limit) => `/json/player/${player_id}/most_kills/${offset}/${limit}`, data => data.kills);
                    Common.scroll_table_generic('#content div#player_top_killers', (offset, limit) => `/json/player/${player_id}/most_deaths/${offset}/${limit}`, data => data.kills);
                });
            });
        }
    });
});
