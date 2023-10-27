const regions = {
    id: 'regions',
    defaults: {
        markers: []
    },
    
    beforeInit: function(chart) {
        /*console.log("Plugin initialized 1: "+JSON.stringify(chart.options.plugins.regions));
        chart.regions = options.regions;*/
    },
    beforeDatasetsDraw: function(chart,_,options) {
        const ctx = chart.ctx;
        const colors = {
            reactor: 'rgba(192,64,64,0.1)',
            overmind: 'rgba(64,64,192,0.1)'
        };
        ctx.save();
        const xAxis = chart.scales.x,yAxis = chart.scales.y;
        for(const [building, markers] of Object.entries(chart.options.plugins.regions.markers)) {
            let start = undefined;
            for(const marker of markers) {
                ctx.fillStyle = colors[marker.building.name];
                if (marker.type == 'destroy') {
                    if (start === undefined) {
                        start = xAxis.getPixelForValue(marker.time);
                    }
                } else if (start !== undefined) {
                    let end = xAxis.getPixelForValue(marker.time);
                    ctx.fillRect(Math.min(start,end), yAxis.top, Math.abs(end - start), yAxis.bottom - yAxis.top);
                    start = undefined;
                }
            }
        }
        ctx.restore();
    }
};

document.addEventListener("DOMContentLoaded", event => {
    const formatPopup = (title, lines) => Common.createEl('DIV', {}, "container noscroll", Common.createEl('TABLE', {}, [], [
        Common.createEl('THEAD', {}, [], Common.createEl('TR', {}, [], Common.createEl('TH', {}, [], title))),
        Common.createEl('TBODY', {}, [], lines.map(line => Common.createEl('TR', {}, [], Common.createEl('TD', {}, [], line))))
    ])).outerHTML;
    const range = n => Array.from({ length: n }, (v, i) => i);
    const teamColors = {
        spectator: range(31).map(v => '#7f7f7f'),
        alien:     range(31).map(v => 'rgb('+(7 + 8 * v)+','+(7 + 2 * v)+','+(7 + 2 * v)+')').reverse(),
        human:     range(31).map(v => 'rgb('+(7 + 2 * v)+','+(7 + 2 * v)+','+(7 + 8 * v)+')').reverse()
    };
    const eventTypes = {
        kill: {
            value: function(s,evs,e,v) { return s.team != evs[e.killed_id].session.team ? v + 1 : v - 1.5; },
            tooltip: function(s,evs,e) {
                if (e.assist_id != null && evs[e.assist_id] == null) {
                    console.log("Strange, assist with no session data for assistant.");
                }
                return formatPopup('Kill',[
                    Common.format_text(s.name),
                    'killed',
                    Common.format_text(evs[e.killed_id].session.name),
                    'with',
                    Common.format_text(e.weapon.displayname)
                ].concat((e.assist_id != null && evs[e.assist_id] != null) ? [
                    'assisted by',
                    Common.format_text(evs[e.assist_id].session.name)
                ] : [ ]));
            }
        },
        death: {
            value: function(s,evs,e,v) { return evs[e.killer_id] && s.team != evs[e.killer_id].session.team ? v - 0.25 : v; },
            tooltip: function(s,evs,e) {
                if (e.killer_id != null) {
                    return formatPopup('Death',[
                        Common.format_text(s.name),
                        'killed by',
                        Common.format_text(evs[e.killer_id].session.name || ""),
                        'with',
                        Common.format_text(e.weapon.displayname)].concat((e.assist_id != null && evs[e.assist_id] != null) ? [
                            'assisted by',
                            Common.format_text(evs[e.assist_id].session.name)
                        ] : [ ]));
                } else {
                    return formatPopup('Death',[
                        Common.format_text(s.name),
                        'died of',
                        Common.format_text(e.weapon.displayname)
                    ]);
                }
            }
        },
        assist: {
            value: function(s,evs,e,v) { return s.team != evs[e.killed_id].session.team ? v + 0.25 : v; },
            tooltip: function(s,evs,e) {
                return formatPopup('Assist',[
                    Common.format_text(s.name),
                    ' assisted ',
                    (e.killer_id != null ? Common.format_text(evs[e.killer_id].session.name) : '<i>world</i>'),
                    ' vs ',
                    Common.format_text(evs[e.killed_id].session.name)
                ]);
            }
        },
        build: {
            value: function(s,evs,e,v) { return v + (e.building.name == 'reactor' || e.building.name == 'overmind' ? 6 : 1); },
            tooltip: function(s,evs,e) {
                return formatPopup('Build',[ Common.format_text(s.name),'built',Common.format_text(e.building.displayname) ]);
            }
        },
        destroy: {
            value: function(s,evs,e,v) { return e.building.team != s.team ? v + (e.building.name == 'reactor' || e.building.name == 'overmind' ? 12 : 2) : (e.weapon.name == 'MOD_DECONSTRUCT' ? v : v - 3); },
            tooltip: function(s,evs,e) {
                return formatPopup('Destroy',[ Common.format_text(s.name),'destroyed',Common.format_text(e.building.displayname),'with',Common.format_text(e.weapon.displayname) ]);
            }
        },
        team: {
            value: function(s,evs,e,v) { return 0; },
            tooltip: function(s,evs,e) {
                return formatPopup('Team',[ Common.format_text(s.name),'joined',e.team+'s' ]);
            }
        },
        end: {
            value: function(s,evs,e,v) { return v; },
            tooltip: function(s,evs,e) {
                return formatPopup('End',[ Common.format_text(s.name),'left',e.team+'s' ]);
            }
        }
    };
    let buildGraphData = gameData => {
        let colorIndex = 0;
        let datasets = Object.values(gameData.sessions).sort((a,b) => a.index - b.index).map(s => {
            const color = /*hidden ? '#7f7f7f' : */teamColors[s.session.team][(colorIndex++) % teamColors[s.session.team].length];
            return {
                type: 'line',
                label: s.session.name,
                borderColor: color,
                backgroundColor: color,
                // lineTension: 0.2,
                data: s.events.map(e => ({
                    x: e.time,
                    y: e.score,
                    title: eventTypes[e.type].tooltip(s.session, gameData.sessions, e)
                })),
                fill: false,
                hidden: false, // todo
                score: s.events.length ? s.events[s.events.length - 1].score : 0
            };
        });
        let markers = { reactor: [], overmind: [] };
        let minTime = Infinity, maxTime = -Infinity;
        let minScore = 0, maxScore = 0
        Object.values(gameData.sessions).forEach(session => {
            Object.keys(markers).forEach(bname => markers[bname] = markers[bname].concat(session.markers[bname]));
            minTime = Math.min(minTime, session.minTime);
            maxTime = Math.max(maxTime, session.maxTime);
            minScore = Math.min(minScore, session.minScore);
            maxScore = Math.max(maxScore, session.maxScore);
        });
        Object.keys(markers).forEach(bname => {
            markers[bname].sort((a,b) => a.time - b.time);
            if (markers[bname].length <= 0 || markers[bname][0].type == 'destroy') {
                // no building event or destroy as first - assume it exists
                markers[bname].unshift({
                    time: minTime,
                    type: 'build',
                    building: { name: bname }
                });
            } else if (markers[bname][0].type == 'build') {
                // destroy as first event - mark building as dead from start
                markers[bname].unshift({
                    time: minTime,
                    type: 'destroy',
                    building: { name: bname }
                });
            }
            if (markers[bname][markers[bname].length - 1].type == 'destroy') {
                // building dead from marker to end of game
                markers[bname].push({
                    time: maxTime,
                    type: 'build',
                    building: { name: bname }
                });
            };
        });
        return {
            "game": gameData.game,
            "datasets": datasets,
            "markers": markers,
            "minTime": minTime,
            "maxTime": maxTime,
            "minScore": minScore,
            "maxScore": maxScore
        };
    };
    let loadGameData = game_id => {
        return Promise.all([
            fetch(`/json/game/${game_id}`).then(r => r.json()).then(data => data.game),
            fetch(`/json/game/${game_id}/sessions`).then(r => r.json()).then(data => data.sessions)
        ]).then(([ game, sessions ]) => {
            let sessionsById = Object.fromEntries(sessions.map(s => [ s.id, { session: s } ]));
            return Promise.all(sessions.map(async (s, sessionIndex) => fetch(`/json/session/${s.id}/events`).then(r => r.json()).then(eventData => {
                let events = eventData.events.map(e => ({ ...e, time: Date.parse(e.time) })).sort((a,b) => a.time - b.time);
                let markers = { reactor: [], overmind: [] };
                let score = Number(0), minScore = score, maxScore = score;
                for(let event of events) {
                    score = event.score = eventTypes[event.type].value(s, sessionsById, event, score);
                    minScore = Math.min(minScore, score);
                    maxScore = Math.max(maxScore, score);
                    if (event.type == 'build' || event.type == 'destroy') {
                        if (markers[event.building.name] !== undefined) {
                            markers[event.building.name].push({ time: event.time, type: event.type, building: { name: event.building.name } });
                        }
                    }
                }
                return {
                    minScore: minScore,
                    maxScore: maxScore,
                    events: events,
                    markers: markers
                };
            }).then(data => { return [ s.id, {
                index: sessionIndex,
                session: s,
                events: data.events,
                markers: data.markers,
                minScore: data.minScore,
                maxScore: data.maxScore,
                minTime: data.events[0].time,
                maxTime: data.events[data.events.length - 1].time
            } ]; })));
        }).then(sessions => { return {
            'game': game,
            'sessions': Object.fromEntries(sessions)
        }; });
    };
    let initializeGraph = div => {
        const loading = Common.beginLoading(div);
        const anchor = div.querySelector('a.data.game_id');
        const game_id = anchor.getAttribute('href');
        anchor.parentNode.removeChild(anchor);
        const graph = div.classList.contains('graph') ? div : div.querySelector('.graph');
        const wrapper = Common.createEl('DIV');
        wrapper.style.position = 'relative';
        wrapper.style.width = '100%';
        wrapper.style.height = '100%';
        const canvas = document.createElement('CANVAS');
        wrapper.appendChild(canvas);
        div.appendChild(wrapper);
        Promise.all([
            Common.loadGraphLibraries(),
            loadGameData(game_id).then(data => buildGraphData(data))
        ]).then(([ _, { game, datasets, markers, minTime, maxTime, minScore, maxScore }]) => {
            const [ timeDelta, scoreDelta ] = [ maxTime - minTime, maxScore - minScore ];
            const chart = new Chart(canvas, {
                type: 'line',
                data: { "datasets": datasets },
                plugins: [ regions ],
                options: {
                    parsing: false,
                    normalized: true,
                    responsive: true,
                    maintainAspectRatio: false,
                    layout: { autoPadding: false },
                    // aspectRatio: 3.0,
                    animation: {
                        // duration: 500,
                        // onProgress: animation => loading.progress(animation.currentStep / animation.numSteps),
                        // onComplete: loading.complete()
                    },
                    scales: {
                        x: {
                            type: 'linear',
                            ticks: {
                                display: true,
                                color: (context) => /*context.dataset.data[context.dataIndex] >= game.suddendeath < xxx*/ "#ffffff",
                                callback: function(value,index,ticks) {
                                    const delta = (value - minTime) / 60000;
                                    const minutes = delta % 60;
                                    return Math.floor(delta - minutes) + ":" + Math.floor(minutes);
                                }
                            },
                            min: minTime,
                            max: maxTime,
                        },
                        y: {
                            type: 'linear',
                            ticks: {
                                display: true,
                                color: (context) => "#ffffff",
                                callback: (value,index,ticks) => Math.floor(value),
                            },
                            min: minScore,
                            max: maxScore,
                        }
                    },
                    plugins: {
                        // TODO: https://www.chartjs.org/docs/latest/samples/legend/html.html
                        legend: {
                            position: 'top',
                            align: 'start',
                            /* maxWidth: 0.4 * div.layoutWidth,
                            maxHeight: 0.4 * div.layoutHeight, */
                            title: {
                                display: true,
                                color: (context) => '#afafaf',
                                text: "Hold CTRL to zoom/pan or SHIFT to select a region to zoom into.",
                                // text: "Hold <i>CTRL</i> to zoom/pan or <i>SHIFT</i> to select a region to zoom into.",
                            },
                            display: true, // true,
                            labels: {
                                color: (context) => "#ffffff",
                            }
                        },
                        regions: {
                            markers: markers
                        },
                        zoom: {
                            zoom: {
                                wheel: {
                                    enabled: true,
                                    modifierKey: 'ctrl',
                                    speed: 0.25,
                                },
                                drag: {
                                    enabled: true,
                                    modifierKey: 'shift',
                                    // modifierKey: null
                                },
                                pinch: {
                                    enabled: true,
                                },
                                mode: 'xy'
                            },
                            pan: {
                                enabled: true,
                                modifierKey: 'ctrl',
                                mode: 'xy'
                            },
                            limits: {
                                x: { min: minTime - 0.20 * timeDelta, max: maxTime + 0.30 * timeDelta },
                                y: { min: minScore - 0.20 * scoreDelta, max: maxScore + 0.30 * scoreDelta }
                            }
                        },
                        tooltip: {
                            enabled: false,
                            position: 'nearest',
                            external: function(context) {
                                const tooltip = context.tooltip;
                                if (!tooltip) return;
                                let el = wrapper.parentNode.querySelector('div#chartjs-tooltip');
                                if (!el) {
                                    el = Common.createEl('DIV', {
                                        id: 'chartjs-tooltip'
                                    });
                                    el.style.opacity = 1;
                                    el.style.pointerEvents = 'none';
                                    el.style.position = 'absolute';
                                    el.style.transform = 'translate(-50%, -50% )';
                                    el.style.transition = 'all .1s ease';
                                    el.style.zIndex = 1000;
                                    wrapper.parentNode.appendChild(el);
                                }
                                canvas.style.cursor = 'pointer';
                                if (tooltip.opacity === 0) {
                                    el.style.opacity = 0;
                                    return;
                                }
                                el.classList.remove('above','below','no-transform');
                                if (tooltip.yAlign) {
                                    el.classList.add(tooltip.yAlign);
                                } else {
                                    el.classList.add('no-transform');
                                }
                                if (tooltip.body) {
                                    el.innerHTML = tooltip.title;
                                }
                                let parentPos = wrapper.parentNode.getBoundingClientRect();
                                el.style.opacity = 1;
                                el.style.left = parentPos.left + tooltip.caretX + 'px';
                                el.style.top = parentPos.top + tooltip.caretY + 'px';
                                /*
                                el.style.font = tooltip.options.bodyFont.string;
                                el.style.padding = tooltip.options.padding + 'px ' + tooltip.options.padding + 'px';
                                */
                            },
                            callbacks: {
                                title: function(items) {
                                    return items[0].dataset.data[items[0].dataIndex].title;
                                }
                            }                           
                        }
                    }
                }
            });
            window.addEventListener("resize", event => {
                const area = wrapper.getBoundingClientRect();
                chart.canvas.width = area.innerWidth;
                chart.canvas.height = area.innerHeight;
                chart.resize();
            });
            Common.endLoading(div);
        });
        return canvas;
    };
    document.querySelectorAll('#content div#game_events').forEach(div => initializeGraph(div));
});
