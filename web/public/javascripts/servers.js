document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll("#content div#servers").forEach(async div => {   
        Common.scroll_table(div, (offset, limit) => {
            return '/json/servers/'+offset+'/'+limit;
        }, data => {
            return data.servers;
        }, (template, server) => {
            let entry = template.cloneNode(true);
            entry.querySelector('.server').replaceWith(Common.createEl('SPAN', {}, "name text", Common.createEl('A', {
                href: `/server/${server.id}/games`
            }, "", Common.formatText(server.displayname))));
            fetch(`/json/server/${server.id}/games/0/1`).then(r => r.json()).then(async data => {
                entry.querySelector('.map').replaceWith(Common.createEl('SPAN', {}, "name text", data.games.length > 0 ? Common.formatText(data.games[0].map.name) : "N/A"));
                entry.querySelector('.players').replaceWith(Common.createEl('SPAN', {}, "name text", data.games.length > 0 ? `${data.games[0].max_players} (${data.games[0].max_bots - data.games[0].max_players})` : "N/A"));
            });
            return entry;
        });
    });
});
