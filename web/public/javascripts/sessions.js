document.addEventListener("DOMContentLoaded", event => {
    document.querySelectorAll("#content div#sessions").forEach(async div => {
        let game_id = div.querySelector("a.game_id").getAttribute("href");
        let team = div.querySelector("a.team").getAttribute("href");
        Common.scroll_table_generic(div, (offset,limit) => `/json/game/${game_id}/sessions/${team}/${offset}/${limit}`,(data) => data.sessions);
    });
    /*
        $('#content div#sessions').each(function(index,div) {
	var game_id = $(div).find('a.game_id').attr('href');
	var team = $(div).find('a.team').attr('href');
	Common.scroll_table_generic(div,function(offset,limit) {
	    return '/json/game/'+game_id+'/sessions/'+team+'/'+offset+'/'+limit;
	},function(data) {
	    return data.sessions;
	});
        });
        */
});
