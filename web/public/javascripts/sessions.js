document.addEventListener("DOMContentLoaded", event => {
    document.querySelectorAll("#content div#sessions").forEach(async div => {
        const game_id = div.querySelector("a.game_id").getAttribute("href");
        const team = div.querySelector("a.team").getAttribute("href");
        const excludeTeams = [...div.querySelectorAll("a.team.exclude")].map(a => a.getAttribute("href"));
        const template = div.querySelector(".template");
        const container = template.parentElement;
        template.classList.remove('template');        
        container.removeChild(template);
        Common.beginLoading(container);
        Promise.all([
            fetch(`/json/game/${game_id}` ).then(data => data.json()),
            fetch(`/json/game/${game_id}/sessions/${team}/0/1024`).then(data => data.json()),
            ...excludeTeams.map(excludeTeam => fetch(`/json/game/${game_id}/sessions/${excludeTeam}/0/1024`).then(data => data.json()))
        ]).then(([game, data, ...excludeDatas]) => {
            const excludePlayers = new Set(excludeDatas.flatMap(data => data.sessions.map(s => s.player_id)));
            const sessions = data.sessions.filter(s => !excludePlayers.has(s.player_id));
            const sessionsByPlayer = Object.values(sessions.reduce((players, session) => {
                (players[session.player_id] ||= {
                    player_id: session.player_id,
                    player_name: session.player_name,
                    player_url: session.player_url,
                    glicko2: session.glicko2,
                    sessions: []
                }).sessions.push(session);
                return players;
            }, {})).map(e => {
                // Combined session record
                return {
                    start: new Date(Math.min(...e.sessions.map(s => Date.parse(s.start)))).toUTCString(),
                    end: new Date(Math.max(...e.sessions.map(s => Date.parse(s.end)))).toUTCString(),
                    score: e.sessions.reduce((score, s) => score + s.score, 0),
                    ping: e.sessions.reduce((ping, s) => ping + s.ping / e.sessions.length, 0),
                    player_id: e.player_id,
                    player_name: e.player_name,
                    player_url: e.player_url,
                    glicko2: e.glicko2,
                    sessions: e.sessions,
                };
            }).sort((a, b) => b.glicko2.rating - a.glicko2.rating).map((e, index) => { e._index = 1 + index; return e; });
            if (team.match(/human|alien/)) {
                sessionsByPlayer.unshift({
                    start: new Date(Math.min(...sessionsByPlayer.map(s => Date.parse(s.start)))).toUTCString(),
                    end: new Date(Math.max(...sessionsByPlayer.map(s => Date.parse(s.end)))).toUTCString(),
                    score: 0, // TODO: Could show avg
                    ping: 0, // TODO: Could show avg or range
                    player_id: 0,
                    player_url: '',
                    player_name: '(team total)',
                    glicko2: {
                        min_range: Math.min(...sessionsByPlayer.map(s => s.glicko2.min_range)),
                        max_range: Math.max(...sessionsByPlayer.map(s => s.glicko2.max_range)),
                        min_rating: Math.min(...sessionsByPlayer.map(s => s.glicko2.min_rating)),
                        max_rating: Math.max(...sessionsByPlayer.map(s => s.glicko2.max_rating)),
                        rd: sessionsByPlayer.reduce((r,s) => r + s.glicko2.rd / sessionsByPlayer.length, 0),
                        rating: sessionsByPlayer.reduce((r,s) => r + s.glicko2.rating / sessionsByPlayer.length, 0),
                        volatility: sessionsByPlayer.reduce((r,s) => r + s.glicko2.volatility / sessionsByPlayer.length, 0),
                        update_count: sessionsByPlayer.reduce((r,s) => r + s.glicko2.update_count / sessionsByPlayer.length, 0),
                    },
                    sessions: [],
                    _index: "",
                });
            }
            sessionsByPlayer.forEach((combinedSession, index) => {
                const teamDisplay = {
                    human:     { color: 'rgba(51,85,128,0.4)', title: '[bsuit] humans' },
                    alien:     { color: 'rgba(128,85,51,0.4)', title: '[tyrant] aliens' },
                    spectator: { color: 'rgba(51,85,51,0.4)' , title: "" }
                };
                const entry = template.cloneNode(true);
                Common.load_fields_generic(entry, combinedSession, {
                    '.f__rank': (session, el) => {
                        const placeholder = Common.createEl('SPAN', {}, [ "loading", "fill" ]);
                        setTimeout(() => {
                            placeholder.replaceWith(Common.rating(session.glicko2, [ placeholder.offsetWidth, placeholder.offsetHeight ]));
                        }, 0);
                        return placeholder;
                    },
                    '.f__sessions': (session, el) => {
                        if (!session.sessions) {
                            return "";
                        }
                        const sessions = session.sessions.some(s => session.sessions.some(t => s !== t && s.start <= t.end && s.start >= t.start))
                              ? session.sessions.map(s => [ s ])
                              : [ session.sessions ];
                        return sessions.map(sessions => {
                            const placeholder = Common.createEl('SPAN', {}, [ "loading", "fill" ]);
                            setTimeout(() => {
                                placeholder.replaceWith(Common.fillBar(sessions.map(s => { return {
                                    start: Date.parse(s.start),
                                    end: Date.parse(s.end),
                                    title: Common.formatText(teamDisplay[team].title),
                                    color: teamDisplay[team].color, // TODO: session has no team but do we need it?
                                }; }), { min: Date.parse(game.game.start), max: Date.parse(game.game.end) }, [ placeholder.offsetWidth, placeholder.offsetHeight ]));
                            }, 0);
                            return placeholder;
                        });
                    },
                });
                container.appendChild(entry);
            });
            template.remove();
            Common.endLoading(container);
        });
    });
});
