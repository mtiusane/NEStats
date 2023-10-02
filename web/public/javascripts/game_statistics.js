/* -- todo: not using new graphjs and still some jquery references... as we got no test data atm
document.addEventListener("DOMContentLoaded", event => {
    var formatPopup = function(title,lines) {
	return [
	    '<div class="container noscroll">',
	    '<table>',
	    `<thead><tr class="title"><th>${title}</th></tr></thead>`,
	    '<tbody>'
	].concat(lines.map(line => `<tr><td>${line}</tr></td>`)).concat([
	    '</tbody>',
	    '</table>',
	    '</div>'
	]).join('');
    };
    let range = (n) => Array.from({length:n},(v,i) => i);
    document.querySelectorAll('#content div#game_statistics').forEach(div => {
	const anchor = div.querySelector('a.data.game_id');
	const game_id = anchor.getAttribute('href');
	anchor.parentNode.removeChild(anchor);
	var graph = div.classList.contains('graph') ? div : div.querySelector('.graph');
	var canvas = document.createElement('<canvas />');
        div.appendChild(canvas);
	let game,events;
	// Chart.defaults.global.pointHitDetectionRadius = 1;
	Chart.defaults.line.aspectRatio = 2.0;

        let loadGame = async function(game_id) {
            return {
                game:   await fetch(`/json/game/${game_id}`).then(r => r.json()).then(data => data.game),
                events: await fetch(`/json/game/${game_id}/events`).then(r => r.json()).then(data => data.events)
            }
        }
        loadGame.then(data => {
            const { game, events } = data;
	    let teamColors = {
		common: range(31).map(v => '#7f7f7f'),
		alien: range(31).map(v => 'rgb('+(7+8*v)+','+(7+2*v)+','+(7+2*v)+')').reverse(),
		human: range(31).map(v => 'rgb('+(7+2*v)+','+(7+2*v)+','+(7+8*v)+')').reverse()
	    };    
    	    // console.log("Loading game sessions: "+game_id);
	    let fields = [
		{ name: 'num_a'            , color: teamColors.alien[0] },
		{ name: 'momentum_a'       , color: teamColors.alien[2] },
		{ name: 'mine_efficiency_a', color: teamColors.alien[4] },
		{ name: 'bp_a'             , color: teamColors.alien[6] },
		{ name: 'building_value_a' , color: teamColors.alien[8] },
		{ name: 'credits_a'        , color: teamColors.alien[10] },
		{ name: 'team_value_a'     , color: teamColors.alien[12] },
		// human
		{ name: 'num_h'            , color: teamColors.human[0] },
		{ name: 'momentum_h'       , color: teamColors.human[2] },
		{ name: 'mine_efficiency_h', color: teamColors.human[4] },
		{ name: 'bp_h'             , color: teamColors.human[6] },
		{ name: 'building_value_h' , color: teamColors.human[8] },
		{ name: 'credits_h'        , color: teamColors.human[10] },
		{ name: 'team_value_h'     , color: teamColors.human[12] },
		// common
		{ name: 'mine_rate'        , color: teamColors.common[0] }
	    ];
	    let datasets = fields.map(def => {
		let values = events.filter((e,i,a) => (i == 0) || (e[def.name] != a[i-1][def.name])).map(e => {
		    return {
			x: new Date(e.time),
			y: Number(e[def.name]),
			title: formatPopup(def.name,[ e[def.name] ])
		    };
		});
		let min = values.reduce(function(a,b) { return (a.y < b.y) ? a : b; }, values[0]).y;
		let max = values.reduce(function(a,b) { return (a.y < b.y) ? b : a; }, values[0]).y;
		let d = max - min;
		min += 0.05*d;
		max -= 0.05*d;
		return {
		    label: def.name,
		    borderColor: def.color,
		    backgroundColor: def.color,
		    data: values.map(function(e) {
			return {
			    x: e.x,
			    y: (e.y - min) / d,
			    title: e.title
			};
		    }),
		    fill: false,
		    hidden: false
		};
	    });
	    var chart = new Chart(canvas, {
		type: 'line',
		data: { datasets: datasets, },
		options: {
		    responsive: true,
		    maintainAspectRatio: true,
		    title: { display: false, text: 'Game statistics', fontColor: 'lightgray' },
		    scales: {
			xAxes: [
			    {
				type: 'time',
				time: {
				    round: 'second',
				    unit: 'minute',
				    minUnit: 'minute',
				    displayFormats: { 'minute': 'hh:mm' },
				    unitStepSize: '1',
				    min: game.start
				},
				ticks: {
				    fontColor: 'lightgray'
				}
			    }
			],
                        yAxes: [
                            {
                                ticks: {
                                    fontColor: 'lightgray'
                                }
                            }
                        ]
		    },
		    hover: { mode: 'single', animationDuration: 400, },
		    zoom: { enabled: true, mode: 'xy', limits: { min: 0.25, max: 4 } },
		    pan: { enabled: true, mode: 'xy' },
		    legend: {
			display: false,
			position: 'bottom',
			labels: {
			    boxWidth: 12,
			    fontColor: 'white',
			    usePointStyle: true,
			    // fontSize: 10,
			    // padding: 8,
			    generateLabels: function(chart) {
				var data = chart.data;
				return data.datasets.map((dataset, i) => {
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
				padding: tooltip.yPadding+'px '+tooltip.xPadding+'px'
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
            chart.render();
            $(window).trigger('resize');
	    
	    canvas.hover(function() {
		Common.disableScroll();
		canvas.on('game_statistics.mousewheel',false);
	    },function() {
		Common.enableScroll();
		canvas.off('game_statistics.mousewheel');
	    });
	});
    });
});
*/
