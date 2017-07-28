$(document).ready(function() {
    var formatPopup = function(title,lines) {
	return [
	    '<div class="container noscroll">',
	    '<table>',
	    '<thead><tr class="title"><th>',title,'</th></tr></thead>',
	    '<tbody>'
	].concat($.map(lines,function(line) { return '<tr><td>'+line+'</tr></td>'; })).concat([
	    '</tbody>',
	    '</table>',
	    '</div>'
	]).join('');
    };
    $('#content div#game_events').each(function(index) {
	var div = $(this);
	var anchor = div.find('a.data.game_id');
	var game_id = anchor.attr('href');
	anchor.remove();
	var graph = div.hasClass('graph') ? div : div.find('.graph');
	var canvas = $('<canvas />').appendTo(div);
	var game,sessions;
	// Chart.defaults.global.pointHitDetectionRadius = 1;
	Chart.defaults.line.aspectRatio = 2.0;
	$.when(
	    $.getJSON('/json/game/'+game_id,function(data) { game = data.game; }),
	    $.getJSON('/json/game/'+game_id+'/sessions',function(data) { sessions = data.sessions; })
	).then(function() {
    	    // console.log("Loading game sessions: "+game_id);
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
			if (e.assist_id != null && eventsBySession[e.assist_id] == null) {
			    console.log("Strange, assist with no session data for assistant.");
			}
			return formatPopup('Kill',[
			    Common.format_text(s.name),
			    'killed',
			    Common.format_text(eventsBySession[e.killed_id].session.name),
			].concat((e.assist_id != null && eventsBySession[e.assist_id] != null) ? [
			    'assisted by',
			    Common.format_text(eventsBySession[e.assist_id].session.name)
			] : [ ]));
		    }
		},
		death  : {
		    value  : function(v) { return v-0.25; },
		    tooltip: function(s,e) {
			if (e.killer_id != null) {
			    if (e.assist_id != null && eventsBySession[e.assist_id] == null) {
				console.log("Strange, assisted death with no assistant.");
			    }
			    return formatPopup('Death',[
				Common.format_text(s.name),
				'killed by',
				Common.format_text(eventsBySession[e.killer_id].session.name),
				'with',
				Common.format_text(e.weapon)].concat((e.assist_id != null && eventsBySession[e.assist_id] != null) ? [
				    'assisted by',
				    Common.format_text(eventsBySession[e.assist_id].session.name)
				] : [ ]));
			    return result;
			} else {
			    return formatPopup('Death',[
				Common.format_text(s.name),
				'died of',
				e.weapon
			    ]);
			}
		    }
		},
		assist : {
		    value  : function(v) { return v+0.25; },
		    tooltip: function(s,e) {
			return formatPopup('Assist',[
			    Common.format_text(s.name),
			    ' assisted ',
			    (e.killer_id != null ? Common.format_text(eventsBySession[e.killer_id].session.name) : '<i>world</i>'),
			    ' vs ',
			    Common.format_text(eventsBySession[e.killed_id].session.name)
			]);
		    }
		},
		build  : {
		    value  : function(v) { return v+1; },
		    tooltip: function(s,e) {
			return formatPopup('Build',[ Common.format_text(s.name),'built',Common.format_text(e.building) ]);
		    }
		},
		destroy: {
		    value  : function(v) { return v+2; },
		    tooltip: function(s,e) {
			return formatPopup('Destroy',[ Common.format_text(s.name),'destroyed',Common.format_text(e.building),'with',Common.format_text(e.weapon) ]);
		    }
		},
		team   : {
		    value  : function(v) { return 0; },
		    tooltip: function(s,e) {
			return formatPopup('Team',[ Common.format_text(s.name),'joined',e.team+'s' ]);
		    }
		},
		end    : {
		    value  : function(v) { return v; },
		    tooltip: function(s,e) {
			return formatPopup('End',[ Common.format_text(s.name),'left',e.team+'s' ]);
		    }
		}
	    };
	    var minTime = game.start, maxTime = game.start;
	    var minScore = 0, maxScore = 0;
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
		    var minTime = Math.min(minTime, $.map(data, function(e) { return e.x; }));
		    var maxTime = Math.max(maxTime, $.map(data, function(e) { return e.x; }));
		    var minScore = Math.min(minScore, $.map(data, function(e) { return e.y; }));
		    var maxScore = Math.max(maxScore, $.map(data, function(e) { return e.y; }));
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
		var minRange = { x: minTime, y: minScore };
		var maxRange = { x: maxTime, y: maxScore };
		var chart = new Chart(canvas, {
		    type: 'line',
		    data: {
			datasets: datasets,
		    },
		    options: {
			responsive: true,
			maintainAspectRatio: true,
			title: {
			    display: true,
			    text: 'Game events',
			    fontColor: 'lightgray'
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
					/* unitStepSize: '1', */
					min: game.start
				    },
				    ticks: {
					autoSkip: true,
					mode: 'linear',
					source: 'auto', // 'data', 'labels'
					bounds: 'data',
					fontColor: 'lightgray'
				    },
				}
			    ]
			},
			hover: {
			    mode: 'single',
			    animationDuration: 400,
			},
			pan: {
			    enabled: true,
			    mode: 'xy',
			    rangeMin: minRange,
			    rangeMax: maxRange
			},
			zoom: {
			    enabled: true,
			    /* drag: true, */
			    mode: 'xy',
			    rangeMin: minRange,
			    rangeMax: maxRange
			},
			legend: {
			    display: true,
			    position: 'bottom',
			    labels: {
				boxWidth: 12,
				fontColor: 'white',
				usePointStyle: true,
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
			},
			events: [
			    'mousewheel',
			    'mousedown',
			    'mousemove', 'click', 'mouseout',
			    'touchstart', 'touchmove', 'touchend'
			],
		    }
		});
		
		canvas.hover(function() {
		    Common.disableScroll();
		    for(var eventName in [
			'mousewheel',
			'mousedown',
			'mousemove', 'click', 'mouseout',
			'touchstart', 'touchmove', 'touchend'
		    ]) {
			canvas.on(eventName+'.game_events',false);
		    }
		},function() {
		    Common.enableScroll();
		    canvas.off('.game_events');
		});
		/*
		$(window).bind('resize',function() {
		    console.log("RESIZE: ",div.width()," ",div.height());
		    canvas.width(div.width()).height(div.height());
		});*/
	    });
	});
    });
});
