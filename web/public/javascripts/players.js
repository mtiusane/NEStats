$(document).ready(function() {
    Common.scroll_table_multi('#content div#players',{
	'a.data.server_id': function(href) {
	    $.get('/json/server/'+href,function(data) {
		$(div).find('.f_server_name').html(data.name);
	    });
	    return function(offset,limit) {
		return '/json/server/'+href+'/players/'+offset+'/'+limit;
	    };
	},
	'a.data.map_id': function(href) {
	    return function(offset,limit) {
		return '/json/map/'+href+'/players/'+offset+'/'+limit;
	    };
	}
    },function(data) {
	return data.players;
    },function(template,data,index) {
	var player = data.player;
	var entry = template.clone();
	entry.find('.f_index').html('<span class="number">'+(1+index)+'</span>');
	entry.find('.f_rank').html(Common.rating(data.glicko2.rating,data.glicko2.rd));
	entry.find('.f_name').html('<span class="name text"><a href="/player/'+player.id+'">'+player.name+'</a></span>');
	entry.find('.f_total_games').html('<span class="number">'+player.total_games+' ('+player.total_sessions+')</span>');
	entry.find('.f_total_playtime').html('<span class="number">'+Common.format_duration(player.total_time)+'</span>');
	entry.find('.f_kills').html(Common.bar(player.total_kills,Common.sum([player.total_kills,player.total_deaths,player.total_bdeaths]),null,player.total_kills,Common.sum([player.total_deaths,player.total_bdeaths])));
	entry.find('.f_assists').html(player.total_assists);
	entry.find('.f_buildings').html(Common.bar(player.total_built,Common.sum([player.total_built,player.total_bkills]),null,player.total_built,player.total_bkills));
	entry.find('.f_building_kd').html(player.total_deaths > 0 ? (player.total_bkills / player.total_deaths).toFixed(2) : "N/A");
	entry.find('.f_team_preference').html(Common.bar(player.total_time_h,player.total_time,null,'<span class="smiley smiley_bsuit"></span>','<span class="smiley smiley_tyrant"></span>'));
	// entry.find('.f_reliability').html(Common.percent(player.total_rqs,player.total_sessions));
	return entry;
    });
});
