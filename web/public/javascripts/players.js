$(document).ready(function() {
    Common.scroll_table_multi('#content div#players',{
	'a.data.server_id': function(href) {
	    $.get('/json/server/'+href,function(data) {
		$('#content div#players').find('.f_server_name').html(data.name);
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
	entry.find('.f_rank').html(Common.rating(data.glicko2));
	entry.find('.f_name').html('<span class="name text"><a href="/player/'+player.id+'">'+Common.format_text(player.displayname)+'</a></span>');
	entry.find('.f_total_games').html('<span class="number">'+player.total_games+'</span>');
	entry.find('.f_total_playtime').html('<span class="number">'+Common.format_duration_minutes(player.total_time)+'</span>');
	entry.find('.f_kills').html(Common.bar({
	    value: player.total_kills,
	    total: Common.sum([player.total_kills,player.total_deaths,player.total_bdeaths]),
	    fill_color: 'rgba(100,63,51,0.66)',
	    empty_color: 'rgba(0,0,0,0.15)'
	}));
	entry.find('.f_kills_count').html(player.total_kills);
	entry.find('.f_deaths_count').html(Common.sum([player.total_deaths,player.total_bdeaths]));
	entry.find('.f_assists').html(player.total_assists);
	entry.find('.f_buildings').html(Common.bar({
	    value: player.total_built,
	    total: Common.sum([player.total_built,player.total_bkills]),
	    fill_color: 'rgba(100,63,51,0.66)',
	    empty_color: 'rgba(0,0,0,0.15)'
	}));
	entry.find('.f_building_kd').html(player.total_deaths > 0 ? (player.total_bkills / player.total_deaths).toFixed(2) : "N/A");
	entry.find('.f_build_count').html(player.total_built);
	entry.find('.f_bkills_count').html(player.total_bkills);
	entry.find('.f_team_preference').html(Common.bar({
	    value: player.total_time_h,
	    total: player.total_time,
	    prefix: '<span class="smiley smiley_bsuit"></span>',
	    suffix: '<span class="smiley smiley_tyrant"></span>',
	    fill_color: 'rgba(51,63,100,0.66)',
	    empty_color: 'rgba(63,100,51,0.66)'
	}));
	// entry.find('.f_reliability').html(Common.percent(player.total_rqs,player.total_sessions));
	return entry;
    });
});
