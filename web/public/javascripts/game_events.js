$(document).ready(function() {
    $('#content div#game_events').each(function(index) {
	var div = $(this);
	var game_id = div.find('a.data.game_id').attr('href');
	var graph = div.hasClass('graph') ? div : div.find('.graph');
	var canvas = $('<canvas />').width(div.width).height(div.height).appendTo(div);
	var game,sessions;
	// Chart.defaults.global.pointHitDetectionRadius = 1;
	$.when(
	    $.getJSON('/json/game/'+game_id,function(data) { game = data.game; }),
	    $.getJSON('/json/game/'+game_id+'/sessions',function(data) { sessions = data.sessions; })
	).then(function() {
    	    console.log("Loading game sessions: "+game_id);
	    var eventsBySession = { };
	    var teamColors = {
		spectator: $.map(_.range(31), function(v) { return '#7f7f7f'; }),
		alien: $.map(_.range(31), function(v) { return 'rgb('+(7+8*v)+','+(7+2*v)+','+(7+2*v)+')'; }).reverse(),
		human: $.map(_.range(31), function(v) { return 'rgb('+(7+2*v)+','+(7+2*v)+','+(7+8*v)+')'; }).reverse()
	    };
	    var eventTypes = {
		kill   : {
		    value  : function(v) { return v+1; },
		    tooltip: function(s,e) {
			var result = eventsBySession[e.killer_id].session.name+" killed "+eventsBySession[e.killed_id].session.name;
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
		    tooltip: function(s,e) {
			if (e.killer_id != null) {
			    var result = eventsBySession[e.killed_id].session.name+" killed by "+eventsBySession[e.killer_id].session.name;
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
			    return eventsBySession[e.killed_id].session.name+" killed by "+e.weapon;
			}
		    }
		},
		assist : {
		    value  : function(v) { return v+0.25; },
		    tooltip: function(s,e) {
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
		    tooltip: function(s,e) {
			return "Built "+e.building;
		    }
		},
		destroy: {
		    value  : function(v) { return v+2; },
		    tooltip: function(s,e) {
			return "Destroyed "+e.building+" with "+e.weapon;
		    }
		},
		team   : {
		    value  : function(v) { return 0; },
		    tooltip: function(s,e) {
			return s.name+" joined "+e.team+'s';
		    }
		},
		end    : {
		    value  : function(v) { return v; },
		    tooltip: function(s,e) {
			return s.name+" left "+e.team+'s';
		    }
		}
	    };
	    $.when.apply($,$.map(sessions, function(s) {
		return $.getJSON('/json/session/'+s.id+'/events', function(data) {
		    eventsBySession[s.id] = { session: s, events: data.events };
		});
	    })).then(function() {
		var index = 0;
		var datasets = $.grep($.map(eventsBySession, function(set, id) {
		    var events = set.events;
		    events.sort(function(a,b) {
			return new Date(a.time) - new Date(b.time)
		    });
		    var score = Number(0);
		    for(var i=0;i<events.length;++i) {
			score = eventTypes[events[i].type].value(score);
			events[i].score = score;
		    }
		    var data = $.map(events, function(e) {
			return {
			    x: e.time,
			    y: e.score,
			    title: eventTypes[e.type].tooltip(set.session,e)
			};
		    });
		    var hidden = Math.abs(score) <= 0;
		    var color = hidden ? '#7f7f7f' : teamColors[set.session.team][index++];
		    return {
			label: set.session.name,
			borderColor: color,
			backgroundColor: color,
			data: data,
			fill: false,
			hidden: hidden,
			score: score
		    }
		}),function(set) {
		    return !set.hidden;
		}).sort(function(a,b) { return b.score - a.score; });
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
				    // display: false,
				    type: 'time',
				    time: {
					round: 'second',
					unit: 'minute',
					minUnit: 'minute',
					displayFormats: {
					    'minute': 'hh:mm'
					},
					unitStepSize: '1',
					min: game.start
				    },
				    ticks: {
					fontColor: 'lightgray'
				    },
				}
			    ]
			},
			hover: {
			    mode: 'single',
			    animationDuration: 400,
			},
			zoom: {
			    enabled: true,
			    mode: 'xy',
			    limits: {
				min: 0.25,
				max: 4
			    }
			},
			pan: {
			    enabled: true,
			    mode: 'xy'
			},
			legend: {
			    display: true,
			    position: 'bottom',
			    labels: {
				boxWidth: 12,
				fontColor: 'white',
				// usePointStyle: true,
				// fontSize: 10,
				// padding: 8,
				generateLabels: function(chart) {
				    var data = chart.data;
				    return $.map(data.datasets,function(dataset, i) {
					return {
					    text: Common.stripColors(dataset.label),
					    fillStyle: dataset.backgroundColor, // Common.generateFillStyle(canvas,dataset.label),
					    hidden: !chart.isDatasetVisible(i),
					    lineCap: dataset.borderCapStyle,
					    lineDash: dataset.borderDash,
					    lineDashOffset: dataset.borderDashOffset,
					    lineJoin: dataset.borderJoinStyle,
					    lineWidth: dataset.borderWidth,
					    strokeStyle: dataset.borderColor,
					    pointStyle: dataset.pointStyle,
				    
					    // Below is extra data used for toggling the datasets
					    datasetIndex: i
					};
				    });
				}
			    }
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
				el.removeClass('above below no-transform');
				if (tooltip.yAlign) {
				    el.addClass(tooltip.yAlign);
				} else {
				    el.addClass('no-transform');
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
				var top = $(window).scrollTop()+tooltip.caretY;
				if (tooltip.yAlign) {
				    if (tooltip.yAlign == 'above') {
					top -= tooltip.caretSize+tooltip.caretPadding;
				    } else {
					top += tooltip.caretSize+tooltip.caretPadding;
				    }
				}
				var position = $(canvas)[0].getBoundingClientRect();
				el.css({
				    opacity: 1,
				    width: 'auto', // tooltip.width ? (tooltip.width+'px') : 'auto',
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