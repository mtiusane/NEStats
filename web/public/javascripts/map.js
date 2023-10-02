document.addEventListener("DOMContentLoaded", async event => {
    document.querySelectorAll('#content div#map').forEach(div => {
	const el_map_id = div.querySelector('a.data.map_id');
        if (el_map_id) {
            const map_id = el_map_id.getAttribute('href');
            fetch(`/json/map/${map_id}`).then(r => r.json()).then(data => {
                document.querySelectorAll('#content div#map_overall').forEach(container => Common.load_fields_generic(container, data));
            });
        }
    });
});
