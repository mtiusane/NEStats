$(document).ready(function() {
    $('#content div.player').each(function(index) {
	var div = $(this);
	var player_id = div.find('a.data.player_id').attr('href');
	var team = div.find('a.data.team_name');
	$.get('/json/player/'+player_id,function(data) {
	    div.find('.index').html(1+index);
	    div.find('.player').html(data.displayname);
	});
	
    });
});
