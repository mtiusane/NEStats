document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll("div#game").forEach(async div => {   
        const a_game_id = div.querySelector('a.data.game_id');
        const game_id = a_game_id.getAttribute('href');
        a_game_id.remove();
        const template = div.querySelector('.template');
        const table = template.parentNode;
        template.parentNode.removeChild(template);
        template.classList.remove('template');
        table.dataset.loading = true;
        return fetch(`/json/game/${game_id}`).then(r => r.json()).then(data => {
            const entry = template.cloneNode(true);
            Common.load_fields_generic(entry, data.game);
            table.appendChild(entry);
            table.dataset.loading = false;
            return data.game.server_id;
        }).then(async server_id => {
            fetch(`/json/server/${server_id}`).then(r => r.json()).then(server_data => div.querySelectorAll('.f_server_name').forEach(el => {
                el.replaceWith(Common.createEl("span", {}, "", Common.format_text(server_data.displayname)));
            }));
        });
    });
});
