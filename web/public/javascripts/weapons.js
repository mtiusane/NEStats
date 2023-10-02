document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll('#content div#weapons').forEach(div => {
	const el_server_id = div.querySelector('a.data.server_id');
        if (el_server_id) {
            const server_id = el_server_id.getAttribute('href');
            fetch(`/json/server/${server_id}`).then(r => r.json()).then(data => {
	        div.querySelectorAll('.f_server_name').forEach(el => el.replaceWith(Common.createEl("span", {}, "", Common.format_text(data.name))));
	    });
	    Common.scroll_table_generic(div, (offset,limit) =>`/json/server/${server_id}/weapons/${offset}/${limit}`, data => data.weapons);;
	}
    });
});
