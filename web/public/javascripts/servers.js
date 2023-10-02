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
            entry.querySelector('.map').replaceWith(Common.createEl('SPAN', {}, "name text", "(TODO)"));
            entry.querySelector('.players').replaceWith(Common.createEl('SPAN', {}, "name text", "(TODO)"));
	    return entry;
        });
    });
});
