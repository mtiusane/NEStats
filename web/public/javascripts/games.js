document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll('#content div#games').forEach(div => {
        let containers = [];
        let el_server_id = div.querySelector('a.data.server_id');
        if (el_server_id) {
            let server_id = el_server_id.getAttribute('href');
            fetch(`/json/server/${server_id}`).then(r => r.json()).then(data => {
                div.querySelectorAll('.f_server_name').forEach(el => el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.name))));
            });
        }
        let el_map_id = div.querySelector('a.data.map_id');
        if (el_map_id) {
            let map_id = el_map_id.getAttribute('href');
            fetch(`/json/map/${map_id}`).then(r => r.json()).then(data => {
                div.querySelectorAll('.f_map_name').forEach(el => el.innerHTML = data.name);
            });
        }
        Common.scroll_table_generic_multi(div, {
	    'a.data.server_id': href => (offset, limit) => `/json/server/${href}/games/${offset}/${limit}`,
	    'a.data.map_id'   : href => (offset, limit) => `/json/map/${href}/games/${offset}/${limit}`
        }, data => data.games);    
    });
});
