$(document).ready(function() {
    $('#content div#game_events').each(function(index) {
	var div = $(this);
	var game_id = div.find('a.data.game_id').attr('href');
	var canvas = $('<canvas />').width(div.width).height(div.height).appendTo(div);
	var game,sessions;
	// Chart.defaults.global.pointHitDetectionRadius = 1;
	$.when(
	    $.getJSON('/json/game/'+game_id,function(data) { game = data.game; }),
	    $.getJSON('/json/game/'+game_id+'/sessions',function(data) { sessions = data.sessions; })
	).then(function() {
    	    console.log("Loading game sessions: "+game_id);
	    var eventsBySession = { };
	    var eventsByPlayer = { };
	    var teamColors = {
		spectator: $.map(_.range(15), function(v) { return '#7f7f7f'; }),
		alien: $.map(_.range(15), function(v) { return 'rgb('+(15+16*v)+','+(15+4*v)+','+(15+4*v)+')'; }).reverse(),
		human: $.map(_.range(15), function(v) { return 'rgb('+(15+4*v)+','+(15+4*v)+','+(15+16*v)+')'; }).reverse()
	    };
	    var eventTypes = {
		kill   : {
		    value  : function(v) { return v+1; },
		    tooltip: function(e) {
			var result = "Killed "+eventsBySession[e.killed_id].session.name;
			result += " with "+e.weapon;
			if (e.assist_id != null) {
			    if (eventsBySession[e.assist_id] != null) {
				result += " assisted by "+eventsBySession[e.assist_id].session.name;
			    } else {
				console.log("Strange, assist with no session data...");
				result += " assisted by someone";
			    }
			}
			return result;
		    }
		},
		death  : {
		    value  : function(v) { return v-0.25; },
		    tooltip: function(e) {
			if (e.killer_id != null) {
			    var result = "Got killed by "+eventsBySession[e.killer_id].session.name;
			    result += " with "+e.weapon;
			    if (e.assist_id != null) {
				if (eventsBySession[e.assist_id] != null && eventsBySession[e.assist_id].session != null) {
				    result += " assisted by "+eventsBySession[e.assist_id].session.name;
				} else {
				    console.log("Strange, assisted kill with no info about assistant...");
				    result += " assisted by someone";
				}
			    }
			    return result;
			} else {
			    return "Died of: "+e.weapon;
			}
		    }
		},
		assist : {
		    value  : function(v) { return v+0.25; },
		    tooltip: function(e) {
			if (e.killer_id != null) {
			    return "Assisted "+eventsBySession[e.killer_id].session.name;
			} else {
			    console.log("Strange, assist with no killer_id...");
			    return "Assisted someone";
			}
		    }
		},
		build  : {
		    value  : function(v) { return v+1; },
		    tooltip: function(e) {
			return "Built "+e.building;
		    }
		},
		destroy: {
		    value  : function(v) { return v+2; },
		    tooltip: function(e) {
			return "Destroyed "+e.building+" with "+e.weapon;
		    }
		},
		team   : {
		    value  : function(v) { return 0; },
		    tooltip: function(e) {
			return "Joined "+e.team;
		    }
		},
		end    : {
		    value  : function(v) { return v; },
		    tooltip: function(e) {
			return "Left the team (session end)";
		    }
		}
	    };
	    $.when.apply($,$.map(sessions, function(s) {
		return $.getJSON('/json/session/'+s.id+'/events', function(data) {
		    eventsBySession[s.id] = { session: s, events: data.events };
		    if (eventsByPlayer[s.player_id] == null) eventsByPlayer[s.player_id] = {
			player: {
			    id: s.player_id,
			    name: s.name
			},
			team: s.team,
			events: [ ]
		    };
		    eventsByPlayer[s.player_id].events.push.apply(eventsByPlayer[s.player_id].events,$.map(data.events,function(e) {
			return $.extend(e, { session: s });
		    }));
		});
	    })).then(function() {
		var index = 0;
		var datasets = $.map(eventsByPlayer, function(set, id) {
		    var events = set.events;
		    events.sort(function(a,b) {
			return new Date(a.time) - new Date(b.time)
		    });
		    var score = Number(0);
		    for(var i=0;i<events.length;++i) {
			score = eventTypes[events[i].type].value(score);
			events[i].score = score;
		    }
		    var color = teamColors[set.team][index++];
		    return {
			label: set.player.name,
			borderColor: color,
			backgroundColor: color,
			data: $.map(events, function(e) {
			    return {
				x: e.time,
				y: e.score,
				title: eventTypes[e.type].tooltip(e)
			    };
			}),
			fill: false
		    }
		});
		var chart = new Chart(canvas, {
		    type: 'line',
		    data: {
			datasets: datasets,
		    },
		    options: {
			title: {
			    display: true,
			    text: 'Game events',
			},
			scales: {
			    xAxes: [
				{
				    type: 'time',
				    time: {
					round: 'second',
					unit: 'second',
					minUnit: 'second',
					unitStepSize: '60',
					min: game.start,
					max: game.end
				    },
				}
			    ]
			},
			hover: {
			    mode: 'single',
			    animationDuration: 400,
			},
			tooltips: {
			    enabled: false,
			    custom: function(tooltip) {
				if (!tooltip) return;
				var el = $('#chartjs-tooltip');
				if (!el[0]) {
				    $('body').append('<div id="chartjs-tooltip"></div>');
				    el = $('#chartjs-tooltip');
				}
				if (!tooltip.opacity) {
				    el.css({ opacity: 0 });
				    $(canvas).each(function(index,el) {
					$(el).css('cursor', 'default');
				    });
				    return;
				}
				$(canvas).css('cursor','pointer');
				el.classList.remove('above', 'below', 'no-transform');
				// el.removeClass('above below no-transform');
				if (tooltip.yAlign) {
				    el.classList.add(tooltip.yAlign);
				    // el.addClass(tooltip.yAlign);
				} else {
				    el.classList.add('no-transform');
				    // el.addClasS('no-transform');
				}
				if (tooltip.body) {
				    var innerHtml = [].concat(
					tooltip.beforeTitle,
					tooltip.title,
					tooltip.afterTitle,
					tooltip.beforeBody,
					tooltip.body.before,
					tooltip.body.lines,
					tooltip.body.after,
					tooltip.afterBody,
					tooltip.beforeFooter,
					tooltip.footer,
					tooltip.afterFooter
				    );
				    el.html(innerHtml.join('\n'));
				}
				var top = tooltip.caretY;
				if (tooltip.yAlign) {
				    if (tooltip.yAlign == 'above') {
					top -= tooltip.caretHeight+tooltip.caretPadding;
				    } else {
					top += tooltip.caretHeight+tooltip.caretPadding;
				    }
				}
				var position = canvas.getBoundingClientRect();
				console.log("P: "+(position.left+tooltip.x)+'px -- '+tooltip.width);
				el.css({
				    opacity: 1,
				    width: tooltip.width ? (tooltip.width+'px') : 'auto',
				    left: (position.left+tooltip.caretX)+'px',
				    top: (position.top+top)+'px',
				    fontFamily: tooltip._fontFamily,
				    fontSize: tooltip.fontSize,
				    fontStyle: tooltip._fontStyle,
				    padding: tooltip.yPadding+'px '+tooltip.xPadding+'px',
				});
			    },
			    callbacks: {
				title: function(items, data) {
				    var itemData = data.datasets[items[0].datasetIndex].data[items[0].index];
				    return itemData.title;
				}
			    }
			}
		    }
		});
	    });
	});
    });
});
