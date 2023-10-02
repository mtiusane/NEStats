Common = {   
    loadingCount: 0,

    _loadingFieldData: new Map(),
    _getFieldData: (element, name) => {
        if (!Common._loadingFieldData.has(element)) {
            return undefined;
        }
        let data = Common._loadingFieldData.get(element);
        if (data === undefined) {
            return undefined;
        }
        return data.get(name);
    },
    _setFieldData: (element, name, value = undefined) => {
        let data = Common._loadingFieldData.get(element);
        if (data === undefined) {
            Common._loadingFieldData.set(element, data = new Map());
        }
        if (value === undefined) {
            data.delete(name);
        } else {
            data.set(name, value);
        }
    },
    _removeFieldData: (element, name) => Common._setFieldData(element, name),

    _expandSelector: (selector) => {
        if (typeof(selector) === 'string') {
            selector = document.querySelectorAll(selector);
        }
        if (typeof(selector.forEach) !== 'function') {
            selector = [ selector ];
        }
        return selector;
    },
    
    // loadingStart: 0,
    onEndLoading: [],
    beginLoading: (element = undefined) => {
        if (Common.loadingCount <= 0) {
            // loadingStart = (new Date()).getTime();
            // Common._loadingFieldData.clear(); -- TODO: need to do this somewhere
        }
        ++Common.loadingCount;
        if (element !== undefined) {
            element.dataset.loading = true;
            element.dataset.loadingCount = (element.dataset.loadingCount || 0) + 1;
            // console.log("Begin loading data for element: "+element);
        }
        // console.log("Loading started, requests: "+Common.loadingCount);
    },
    endLoading: (element = undefined) => {
        if (element !== undefined && element.dataset.loadingCount !== undefined) {
            if (--element.dataset.loadingCount <= 0) {
                delete element.dataset.loadingCount;
                delete element.dataset.loading;
                // console.log("Finished loading data for element: "+element);
            }
        }
        --Common.loadingCount;
        if (Common.loadingCount <= 0) {
            // var loadingEnd = (new Date()).getTime();
            // var loadingDuration = (loadingEnd - loadingStart) / 1000;
            // console.log("Loading finished, total time: "+loadingDuration);
            while(Common.onEndLoading.length > 0) {
                var fn = Common.onEndLoading.shift();
                fn();
            }
            Common.loadingCount = 0;
            Common.loadingStart = 0;
        }
    },
    isLoading: (element = undefined) => {
        if (element) {
            return element.dataset.loading || false;
        } else {
            return Common.loadingCount > 0;
        }
    },

    loadGraphLibraries: () => {
        Common.beginLoading();
        return import("/javascripts/chart.umd.min.js").then(
            () => import("/javascripts/hammer.min.js")
        ).then(
            () => import("/javascripts/chartjs-plugin-zoom.min.js")
        ).then(result => {
            Common.endLoading();
            return result;
        });
    },

    scroll_container: (target, table, link, elements, line) => {
        Common._expandSelector(target).forEach(container => {
            // console.log("Initializing scroll container: ",container," table: ",table);
            let scroll = {
                root: container,
                offset: 0
            };
            let template = table.querySelector('.template');
            template = template.parentElement.removeChild(template);
            template.classList.remove('template');
            const thead = table.querySelector('thead');
            const tbody = table.querySelector('tbody');
            const loadPage = (callback) => {
                const [ offset, total, limit, lastLoad ] = [ 'offset', 'total', 'limit', 'lastLoad' ].map(name => Common._getFieldData(table, name) || 0);
                Common.beginLoading(table);
                fetch(link(offset, limit)).then(r => r.json()).then(data => {
                    let lines = elements(data);
                    lines.forEach((element, index) => tbody.append(line(template, element, offset + index)));
                    Common._setFieldData(table, 'offset', offset + lines.length);
                    Common._setFieldData(table, 'total', data.total);
                    Common._setFieldData(table, 'lastLoad', (new Date()).getTime());
                    Common._setFieldData(table, 'limit', limit);
                    if (callback) callback();
                    Common.endLoading(table);
                });
            };
            Object.entries({
                'offset': 0,
                'total': 0,
                'limit': 25,
                'lastLoad' : (new Date()).getTime()
            }).forEach(([ name, value ]) => Common._setFieldData(table, name, value));
            container.addEventListener("scroll", (event) => {
                const timeSinceLastLoad = (new Date()).getTime() - Common._getFieldData(table, 'lastLoad');
                if (Common._getFieldData(table, 'offset') < Common._getFieldData(table, 'total') && !Common.isLoading(table) &&
                    timeSinceLastLoad >= 500 && container.scrollTop + container.offsetHeight >= container.scrollHeight) {
                    // console.log("Loading page:" +table.data('offset') + ' < ' + table.data('total'));
                    loadPage();
                }
            });
            loadPage();
        });
    },
    
    scroll_table: (target, link, elements, line) => {
        Common._expandSelector(target).forEach(container => {
            Common.scroll_container(container, container.querySelector('table'), link, elements, line);
        });
    },

    replaceField: (field, value) => {
        if (field.tagName == 'SPAN' && field.getAttribute('class') == '') {
            field.replaceWith(value);
        } else if (typeof(value) !== 'string') {
            field.replaceChildren(value);
        } else {
            field.innerHTML = value;
        }
    },

    findFieldType: field => {
        const dateTypes = [
            'f__date', 'f__time', 'f__duration', 'f__duration_minutes', 'f__duration_date'
        ];
        return (dateTypes.some(dt => field.classList.contains(dt))) ? {
            parseValue: value => new Date(value)
        } : {
            parseValue: value => new Number(value)
        };
    },
    loadFieldType: field => {
        let fns = Common._getFieldData(field, 'f__fieldType');
        if (fns === undefined) {
            fns = Common.findFieldType(field);
            Common._setFieldData(field, 'f__fieldType', fns);
        }
        return fns;
    },
    clearFieldType: field => Common._removeFieldData(field, 'f__fieldType'),

    loadFieldValues: (target, data) => {
        Common._expandSelector(target).forEach(selector => {
            /*if (!data || !Array.isArray(data)) {
              console.log("Invalid data...");
              return;
              }*/
            selector.querySelectorAll('.f__parent').forEach(parent => {
                parent.classList.remove('f__parent');
                Object.entries(data).forEach(([ name, value ]) => {
                    const selectorName = 'f_'+name;
                    if (parent.classList.contains(selectorName)) {
                        parent.classList.remove(selectorName);
                        Common.loadFieldValues(parent, value);
                    }
                });
            });
            Object.entries(data).forEach(([ name, value ]) => {
                const selectorName = 'f_'+name;
                selector.querySelectorAll('.'+selectorName).forEach((field, fieldIndex) => {
                    // console.log("Loading field: f_"+name, field);
                    field.classList.remove(selectorName);
                    if (field.tagName == 'A') {
                        if (value != null) {
                            field.setAttribute('href', value);
                        } else {
                            while(field.firstChild) {
                                field.parentNode.appendChild(field.firstChild);
                            }
                            field.parentNode.removeChild(field);
                        }
                    } else if (field.tagName == 'IMG') {
                        if (value != null && value != "") {
                            field.setAttribute('src',value);
                            field.parentNode.querySelectorAll('.imgNotFound').forEach(child => child.parentNode.removeChild(child));
                        } else {
                            field.parentNode.removeChild(field);
                        }
                    } else if (field.classList.contains('f__sum') || field.classList.contains('f__sub')) {
                        let fns = Common.loadFieldType(field);
                        let sum = Common._getFieldData(field, 'f__sum');
                        let parsedValue = fns.parseValue(value);
                        if (sum === undefined) {
                            sum = parsedValue;
                        } else {
                            sum += parsedValue;
                        }
                        Common._setFieldData(field, 'f__sum', sum);
                    } else {
                        Common.replaceField(field, value);
                    }
                });
            });
        });
    },
    
    load_fields_generic: (target, data) => {
        // console.log("Loading generic fields: "+data._index);
        // $.each(selector.find('a.data.field'),function(field_index,field) {
        //     var name = field.attr('href');
        //     if (_.has(data,name)) {
        //      $(field).replaceWith(data[name]);
        //     }
        // });
        return new Promise((resolve, reject) => {
            const targets = Common._expandSelector(target);
            targets.forEach(selector => {
                Common.loadFieldValues(selector, data);
                selector.querySelectorAll('.f__img').forEach((field, index) => {
                    field.classList.remove('f__img');
                    const commonStyle = 'display: inline-block; background: black';
                    field.setAttribute('style', commonStyle);
                });
                selector.querySelectorAll('.f__sum').forEach((field, index) => {
                    field.classList.remove('f__sum');
                    const fns = Common.loadFieldType(field);
                    const sum = Common._getFieldData(field, 'f__sum');
                    Common._removeFieldData(field, 'f__sum');
                    Common.clearFieldType(field);
                    Common.replaceField(field, sum);
                });
                selector.querySelectorAll('.f__sub').forEach((field, index) => {
                    field.classList.remove('f__sub');
                    const fns = Common.loadFieldType(field);
                    const sum = fns.parseValue(field.textContent) - Common._getFieldData(field, 'f__sum');
                    Common._removeFieldData(field, 'f__sum');
                    Common.clearFieldType(field);
                    Common.replaceField(field, sum);
                });
                selector.querySelectorAll('.f__date').forEach((field, index) => {
                    field.classList.remove('f__date');
                    Common.replaceField(field, new Date(field.textContent).toLocaleDateString());
                });
                selector.querySelectorAll('.f__time').forEach((field, index) => {
                    field.classList.remove('f__time');
                    Common.replaceField(field, new Date(field.textContent).toLocaleTimeString());
                });
                selector.querySelectorAll('.f__utcdate').forEach((field, index) => {
                    field.classList.remove('f__utcdate');
                    Common.replaceField(field, new Date(field.textContent).toUTCString().replace(' GMT',''));
                });
                selector.querySelectorAll('.f__duration').forEach((field, index) => {
                    field.classList.remove('f__duration');
                    Common.replaceField(field, Common.format_duration(field.textContent));
                });
                selector.querySelectorAll('.f__duration_minutes').forEach((field, index) => {
                    field.classList.remove('f__duration_minutes');
                    Common.replaceField(field, Common.format_duration_minutes(field.textContent));
                });
                selector.querySelectorAll('.f__duration_date').forEach((field, index) => {
                    field.classList.remove('f__duration_date');
                    Common.replaceField(field, Common.format_duration_minutes(new Number(field.textContent).valueOf() / 1000.0));
                });
                selector.querySelectorAll('.f__text').forEach((field, index) => {
                    field.classList.remove('f__text');
                    Common.replaceField(field, Common.formatText(field.textContent));
                });
                selector.querySelectorAll('.f__bar').forEach((field, index) => {
                    field.classList.remove('f__bar');
                    let neutral = field.querySelector('.bar_neutral');
                    neutral = neutral ? neutral.textContent : null;
                    let text = field.querySelector('.bar_text');
                    text = text ? text.innerHTML : null;
                    let prefix = field.querySelector('.bar_prefix');
                    // prefix = prefix ? prefix.innerHTML : null;
                    let suffix = field.querySelector('.bar_suffix');
                    // suffix = suffix ? suffix.innerHTML : null;
                    let fill_color = field.querySelector('.bar_fillcolor');
                    fill_color = fill_color ? fill_color.textContent : null;
                    let empty_color = field.querySelector('.bar_emptycolor');
                    empty_color = empty_color ? empty_color.textContent : null;
                    let neutral_color = field.querySelector('.bar_neutralcolor');
                    neutral_color = neutral_color ? neutral_color.textContent : null;
                    let center_fill_text = field.classList.contains('bar_center_text');
                    Common.replaceField(field, Common.bar({
                        value: field.querySelector('.bar_value').textContent,
                        total: field.querySelector('.bar_total').textContent,
                        neutral: neutral,
                        text: text,
                        prefix: prefix,
                        suffix: suffix,
                        fill_color: fill_color,
                        empty_color: empty_color,
                        neutral_color: neutral_color,
                        center_fill_text: center_fill_text
                    }));
                });
            });
            resolve(targets);
        });
    },

    scroll_table_multi: (target, selectors, elements, line) => {
        Common._expandSelector(target).forEach(div => {
            for(const selector in selectors) {
                div.querySelectorAll(selector).forEach(field_id => {
                    const url = selectors[selector](field_id.getAttribute('href'));
                    Common.scroll_table(div, url, elements, line);
                    field_id.parentNode.removeChild(field_id);
                });
            }
        });
    },

    scroll_table_generic: (target, link, elements) => {
        Common.scroll_table(target, link, elements, (template, data, index) => {
            const entry = template.cloneNode(true);
            data._index = 1+index;
            Common.load_fields_generic(entry, data);
            return entry;
        });
    },

    scroll_table_generic_multi: (target, selectors, elements) => {
        Common._expandSelector(target).forEach(div => {
            for(const selector in selectors) {
                div.querySelectorAll(selector).forEach(field_id => {
                    var url = selectors[selector](field_id.getAttribute('href'));
                    field_id.parentNode.removeChild(field_id);
                    Common.scroll_table_generic(div, url, elements);
                    // return;
                });
            }
        });
    },

    format_percent: value => Number(100.0 * value).toFixed(2) + '%',

    format_duration: function(seconds) {
        seconds = Number(seconds);
        var hours = Math.floor(seconds / 3600.0);
        seconds -= 3600.0 * hours;
        var minutes = Math.floor(seconds / 60.0);
        seconds -= 60.0 * minutes;
        seconds = Math.floor(seconds);
        seconds = (seconds > 0) ? ((minutes > 0) ? ' ' : '') + seconds + 's' : '';
        minutes = (minutes > 0) ? ((hours > 0) ? ' ' : '') + minutes + 'min' : '';
        hours = (hours > 0) ? hours + 'h' : '';
        return hours + minutes + seconds;
    },

    format_duration_hm: function(seconds)
    {
        seconds = Number(seconds);
        var hours = Math.floor(seconds / 3600.0);
        seconds -= 3600.0 * hours;
        var minutes = Math.floor(seconds / 60.0);
        minutes = (minutes > 0) ? ((hours > 0) ? ' ' : '') + minutes + 'min' : '';
        hours = (hours > 0) ? hours + 'h' : '';
        return hours + minutes;
    },  

    format_duration_minutes: function(seconds) {
        return Common.format_duration(Math.ceil(Number(seconds) / 60.0) * 60.0);
    },

    format_text: text => {
        if (text === undefined) {
            text = "&lt;&lt;undefined&gt;&gt;";
        }
        const result = Common.createEl('SPAN', {}, [ "color7" ]);
        result.innerHTML = '<span>' + text.replace(/\[([A-Za-z0-9]+?)\]|(?:\^([^\^]))|(\^\^)|(.+?)/g, (match, smiley, color, caret, text) => {
            if (smiley) {
                return `<span class=\"smiley smiley_${smiley}\"></span>`;
            } else if (color) {
                const n = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
                return `</span><span class="color${n}">`;
            } else if (caret) {
                return '^';
            } else if (text) {
                return text;
            }
        }) + '</span>';
        return result;
        /*
        return '<span class="color7">'+text
            .replace(/\[(\S+?)\]/g, (match, id) => {
                '<span class="smiley smiley_$1"></span>'
            }
            .replace(/\^(.)([^\^]*)/gi, (match, color, content) => {
                const n = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
                return `<span class="color${n}">${content}</span>`;
            })+'</span>';*/
    },
    formatText: text => Common.format_text(text),

    format_outcome: function(outcome) {
        return '<span class="'+outcome+'">'+outcome+'</span>';
    },

    sum: function(values) {
        return values.reduce(function(p,v) { return Number(p)+Number(v); });
    },

    isDefined: function(value) {
        return !(typeof value === 'undefined' || value === null);
    },

    percent: function(value,total) {
        if (total > 0)
            return Common.format_percent(value/total);
        else
            return "N/A";
    },

    roundTo: function(v,m) {
        return Math.round(v / m) * m;
    },

    rating_size: (aspect, margin) => {
        const a = (typeof aspect !== 'undefined') ? aspect : 4.0;
        const m = (typeof margin !== 'undefined') ? margin : 0.1;
        const ce = document.querySelector('#page');
        const cr = ce.getBoundingClientRect();
        const pa = ce.offsetWidth / ce.offsetHeight;
        if (pa < a) {
            wh = ce.offsetHeight / 8;
            ww = a * wh;
        } else {
            ww = ce.offsetWidth / 4;
            wh = ww / a;
        }
        const ca = a - m;
        const window_a = ww / wh;
        if (ca < window_a) {
            const ch = Common.roundTo(wh, 8);
            return [ Common.roundTo(ch * ca, 16), ch ];
        } else {
            const cw = Common.roundTo(ww, 16);
            return [ cw, Common.roundTo(cw / ca, 8) ];
        }
    },

    bar_size: () => {
        const [ w, h ] = Common.rating_size(8.0);
        return [ 0.5 * w, 0.5 * h ];
    },

    image_size: () => {
        const [ w, h ] = Common.rating_size(8.0);
        return [ 0.25 * w, 1.2 * h ];
    },

    createEl: (tag, attributes = {}, classList = [], text = undefined) => {
        let el = document.createElement(tag);
        for(const [ name, value ] of Object.entries(attributes)) {
            el.setAttribute(name, value);
        }
        if (typeof(classList) === 'string') {
            classList = classList.split(' ').filter(s => s !== '');
        }
        for(const cname of classList) {
            el.classList.add(cname);
        }
        if (text !== undefined) {
            if (Array.isArray(text)) {
                text.forEach(child => el.appendChild(child));
            } else if (typeof(text) === 'object') {
                el.appendChild(text);
            } else {
                el.textContent = text;
            }
        }
        return el;
    },

    createElXML: (tag, attributes = {}, classList = [], text = undefined) => {
        let el = document.createElementNS("http://www.w3.org/2000/svg", tag);
        for(const [ name, value ] of Object.entries(attributes)) {
            el.setAttribute(name, value);
        }
        for(const cname of classList) {
            el.classList.add(cname);
        }
        if (text !== undefined) {
            el.textContent = text;
        }
        return el;
    },

    
    rating: g => {
        const [ cw, ch ] = Common.rating_size();
        const result = Common.createEl("DIV", {}, [ "rating" ]);
        const fontSize = 28; // Number(ch / 3).toFixed(2);
        const fontSizeInfo = 9;
        const empty_color = 'transparent';
        const svg = Common.createElXML("svg", {
            "width"  : cw,
            "height" : ch,
            "viewbox": `0 0 ${cw} ${ch}`,
            "style"  : `background: ${empty_color}`
        });
        if (g.update_count > 0) {
            const [ rangeMin, rangeMax ] = [ Number(g.min_range), Number(g.max_range) ];
            const rangeDelta = rangeMax - rangeMin;
            //var rMin = Number(g.min_rating);
            //var rMax = Number(g.max_rating);
            //var rDelta = rMax - rMin;
            const r = Number(g.rating);
            const rd = Number(g.rd);
            const rdScale = 0.5; // rd / (rangeDelta - 3/2 * rDelta);
            const fill_color = 'rgba(100,63,51,0.66)';
            const stroke_color = '#642e1d';
            const rd_fill_left = cw * (r - rangeMin - (2.0/* - 0.25*/) * rd * rdScale) / rangeDelta;
            const rd_fill_width = cw * (4.0 * rd * rdScale) / rangeDelta;
            const x0 =       rd_fill_width /  4.0,x1 = 3.0*rd_fill_width / 10.0,x2 = rd_fill_width / 2.0;
            const x3 = 2.0 * rd_fill_width / 10.0,x4 =     rd_fill_width /  4.0,x5 = rd_fill_width / 2.0;
            let graph = [ 'm' ].concat([
                rd_fill_left, ch
            ].map(v => Number(v).toFixed(2))).concat([ 'c' ]).concat([
                x0, 0.0, x1, -ch, x2, -ch, x3, 0, x4, ch, x5, ch
            ].map(v => Number(v).toFixed(2))).join(' ');
            /*
              const rd_fill_middle = rd_fill_left + 0.5 * rd_fill_width;
              const extra = '';//'m '+rd_fill_middle.toFixed(2)+' 0 l '+rd_fill_middle.toFixed(2)+' '+ch.toFixed(2);
            */
            const ratingStyle = `font-size: ${fontSize}px; fill: white`;
            const infoStyle = `font-size: ${fontSizeInfo}px; fill: #dfdddc`;
            let text = [];
            text.push(Common.createElXML("text", {
                "style"            : infoStyle,
                "text-anchor"      : "start",
                "dominant-baseline": "hanging",
                "x"                : 1,
                "y"                : 1
            }, [], rangeMin.toFixed(0)));
            text.push(Common.createElXML("text", {
                "style"            : infoStyle,
                "text-anchor"      : "end",
                "dominant-baseline": "hanging",
                "x"                : cw - 1,
                "y"                : 1
            }, [], rangeMax.toFixed(0)));
            text.push(Common.createElXML("text", {
                "style"            : infoStyle,
                "text-anchor"      : "end",
                "dominant-baseline": "bottom",
                "x"                : Math.min(90, (0.5 + (r - rd - rangeMin) / rangeDelta * 99.0 - 4.0)).toFixed(2)+"%",
                "y"                : (ch - fontSizeInfo / 2).toFixed(2)
            }, [], (r - rd).toFixed(0)));
            text.push(Common.createElXML("text", {
                "style"            : infoStyle,
                "text-anchor"      : "start",
                "dominant-baseline": "bottom",
                "x"                : Math.min(90, (0.5 + (r + rd - rangeMin) / rangeDelta * 99.0)).toFixed(2)+"%",
                "y"                : (ch - fontSizeInfo / 2).toFixed(2)
            }, [], (r + rd).toFixed(0)));
            text.push(Common.createElXML("text", {
                "style"            : ratingStyle,
                "text-anchor"      : "middle",
                "dominant-baseline": "middle",
                "x"                : "50%",
                "y"                : "50%"
            }, [], r.toFixed(0)));
            const path = Common.createElXML("path", {
                "d"           : graph,
                "fill"        : fill_color,
                "stroke"      : stroke_color,
                "stroke-width": 1,
            });
            svg.appendChild(path);
            text.forEach(el => svg.appendChild(el));
        } else {
            const empty_color = 'transparent';
            const fill_color = '#6f6767';
            const text = Common.createElXML("text", {
                "style"            : `font-size: ${fontSize}; fill: ${fill_color}`,
                "text-anchor"      : "middle",
                "dominant-baseline": "middle",
                "x"                : "50%",
                "y"                : "50%"
            }, [], "N/A");
            svg.appendChild(text);
        }
        result.appendChild(svg);
        return result;
    },
    
    bar: params => {
        // TODO: Rename centerText as it's used to override default layout such that fill% is always shown but always at center
        const [ cw, ch ] = Common.bar_size();
        const fill_color = params.fill_color || '#3355ff';
        const empty_color = params.empty_color || '#ff5533';
        const neutral_color = params.neutral_color || '#555555';
        const resultWrapper = Common.createEl('SPAN', [], [ "field", "barWithCaptions" ]);
        const result = Common.createEl('SPAN', {}, [ "bar" ]);
        const centerText = Common.isDefined(params.center_fill_text);
        const hasText = Common.isDefined(params.text);
        const total = Number(params.total);
        const svg = Common.createElXML('svg', { "width": cw, "height": ch, "viewbox": `0 0 ${cw} ${ch}` });
        if (total > 0.0) {
            const fill = 100.0 * Number(params.value) / total;
            const neutral = Common.isDefined(params.neutral) ? 100.0 * Number(params.neutral) / total : 0.0;
            const empty = 100.0 - fill - neutral;
            const fill_text = hasText ? '' : ((fill >= 33.0 || centerText) ? fill.toFixed(2)+'%' : '');
            const empty_text = hasText ? '' : ((empty >= 33.0 && !centerText) ? empty.toFixed(2)+'%' : '');
            const neutral_text = hasText ? '' : ((neutral >= 33.0 && !centerText) ? neutral.toFixed(2)+'%' : '');
            svg.appendChild(Common.createElXML('rect', {
                "x": 0, "y": 0, "width": Number(fill).toFixed(2)+"%", "height": "100%", "fill": fill_color
            }));
            if (!centerText && fill_text != "") {
                let el = Common.createElXML('text', {
                    "x"                : Number(fill/2).toFixed(2)+"%",
                    "y"                : "50%",
                    "dominant-baseline": "middle",
                    "text-anchor"      : "middle",
                    "style"            : "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white"
                });
                el.innerHTML = fill_text;
                svg.appendChild(el);
            }
            if (neutral > 0.0) {
                svg.appendChild(Common.createElXML('rect', {
                    "x"     : Number(fill).toFixed(2)+"%",
                    "y"     : "0",
                    "width" : Number(neutral).toFixed(2)+"%",
                    "height": "100%",
                    "fill"  : neutral_color
                }));
                if (!centerText && neutral_text != "") {
                    let el = Common.createElXML('text', {
                        "x": Number(fill + neutral/2).toFixed(2)+"%",
                        "y": "50%",
                        "dominant-baseline": "middle",
                        "ext-anchor": "middle",
                        "style": "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white"
                    });
                    el.innerHTML = neutral_text;
                    svg.appendChild(el);
                }
            }
            svg.appendChild(Common.createElXML('rect', {
                "x"     : Number(fill+neutral).toFixed(2)+"%",
                "y"     : "0",
                "width" : Number(empty).toFixed(2)+"%",
                "height": "100%",
                "fill"  : empty_color
            }));
            if (!centerText && empty_text != "") {
                let el = Common.createElXML('text', {
                    "x": Number(fill+neutral+empty/2).toFixed(2)+"%",
                    "y": "50%",
                    "dominant-baseline": "middle",
                    "text-anchor": "middle",
                    "style": "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white"
                });
                el.innerHTML = empty_text;
                svg.appendChild(el);
            }
            if (centerText) {
                let el = Common.createElXML('text', {
                    "x": "50%",
                    "y": "50%",
                    "dominant-baseline": "middle",
                    "text-anchor": "middle",
                    "style": "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white"
                });
                el.innerHTML = fill_text;
                svg.appendChild(el);
            }
        } else {
            svg.setAttribute("style", `background: ${empty_color}`);
            svg.appendChild(Common.createElXML('text', {
                "style": "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white",
                "text-anchor": "middle",
                "dominant-baseline": "middle",
                "x": "50%",
                "y": "50%"
            }, [], "N/A"));
        }
        if (hasText) {
            let el = Common.createElXML('text', {
                "style": "font-size: "+Number(ch/3).toFixed(2)+"px; fill: white",
                "text-anchor": "middle",
                "dominant-baseline": "middle",
                "x":"50%",
                "y":"50%"
            });
            el.innerHTML = params.text;
            svg.appendChild(el);
        }
        result.appendChild(svg);
        if (Common.isDefined(params.prefix)) {
            let el = Common.createEl('SPAN', {}, [ "prefix" ]);
            if (typeof(params.prefix) === 'string') {
                el.innerHTML = Common.format_text(params.prefix);
            } else {
                el.appendChild(params.prefix);
            }
            resultWrapper.appendChild(el);
        }
        resultWrapper.append(result);
        if (Common.isDefined(params.suffix)) {
            let el = Common.createEl('SPAN', {}, [ "suffix" ]);
            if (typeof(params.prefix) === 'string') {
                el.innerHTML = Common.format_text(params.suffix);
            } else {
                el.appendChild(params.suffix);
            }
            resultWrapper.appendChild(el);
        }
        return resultWrapper;
    },

    extractIcons: function(text, color) {
        /*
          var parts = [ ];
          var start = 0;
          while(start < text.length) {
          var next = text.indexOf('[', start);
          var 
          }
        */
    },

    extractColors: text => {
        var parts = [ ];
        var start=0;
        var color='7';
        while(start < text.length) {
            var next = text.indexOf('^', start);
            if (next != -1) {
                if (next > start) parts.push({ color: color, text: text.substr(start, next-start) });
                color = text.charAt(next+1);
                start = next+2;
            } else {
                parts.push({ color: color, text: text.substr(start) });
                start = text.length;
            }
        }
        return parts;
    },

    combineTextFromColors: parts => parts.map(p => p.text).join(''),

    stripColors: text => Common.combineTextFromColors(Common.extractColors(text)),

    mapColor: color => {
        const index = (color.charCodeAt(0)-'0'.charCodeAt(0)) % 16;
        const colors = [
            '#333333', '#ff0000', '#00ff00', '#ffff00',
            '#0000ff', '#00ffff', '#ff00ff', '#ffffff',
            '#ff7f00', '#7f7f7f', '#ff9919', '#007f7f',
            '#7f007f', '#007fff', '#7f00ff', '#3399cc'
        ];
        return colors[index];
    },
    
    generateFillStyle: (canvas, text) => {
        const parts = Common.extractColors(text);
        const letters = Common.combineTextFromColors(parts);
        const ctx = canvas.getContext("2d");
        const width = ctx.measureText(letters).width;
        const gradient = ctx.createLinearGradient(0, 0, width, 0);
        var offset = Number(0.0);
        parts.forEach(part => {
            gradient.addColorStop(offset, Common.mapColor(parts[i].color));
            offset += Number(part.text.length) / Number(letters.length);
        })
        return gradient;
    },

    wrapSVG: text => {
        const [cw, ch] = Common.rating_size();
        return [].concat(
            '<svg xmlns="http://www.w3.org/2000/svg"  >', // width="'+cw+'" height="'+ch+'"
            '<foreignObject width="100%" height="100%">',
            '<div xmlns="http://www.w3.org/1999/xhtml" style="font-size:40px">',
            text,
            '</div>',
            '</foreignObject>',
            '</svg>'
        );
    },

    disableScroll: function() {
        /*
        var content = $('#content_wrapper.jspScrollable:first');
        var container = content.find('.jspContainer');
        var jsp = content.data('jsp');
        if (jsp !== undefined) {
            jsp.disableMouseWheel();
            }
        */
    },
    
    enableScroll: function() {
        /*
        var content = $('#content_wrapper.jspScrollable:first');
        var jsp = content.data('jsp');
        if (jsp !== undefined) {
            jsp.enableMouseWheel();
            }
        */
    },  

    updateFullSize: (menu, page) => {
        /*
        $('.jspScrollable').each(function(index,field) {
            field = $(field);
            var jsp = field.data('jsp');
            if (jsp !== undefined) {
                field.outerHeight(field.parent().outerHeight());
                field.outerWidth(Math.min(field.parent().outerWidth(), $('#page').innerWidth()));
                jsp.reinitialise();
            }
            })OA;
            */
    },

    isResizing: false,
    // mainScrollPane: undefined,
    resizeWindow: (content, menu, page) => {
        if (!Common.isResizing) {
            Common.isResizing = true;
            /*
            content.css({ width: 1, height: 1 });
            content.css({ width: page.width(), height: page.height() });
            if (Common.mainScrollPane !== undefined) {
                // -- Common.mainScrollPane.destroy();
                Common.mainScrollPane = undefined;
            }
            Common.mainScrollPane = content.jScrollPane({
                autoReinitialise: false,
                showArrows: false,
                maintainPosition: true,
                verticalGutter: 0,
                horizontalGutter: 0,
                contentWidth: '100%'
            });
            */
            Common.isResizing = false;
            // -- Common.updateFullSize(menu,page);
        }
    },

    resizePending: false,
    resizeAfterAllLoads: function() {
        if (!Common.resizePending) {
            Common.resizePending = true;
            Common.onEndLoading.push(() => {
                const [ menu, page, content ] = [ '#menu', '#page', '#content_wrapper' ].map(id => document.querySelector(id));
                Common.resizeWindow(content, menu, page);
                Common.resizePending = false;
            });
        }
    }
    
};

document.addEventListener("DOMContentLoaded", event => {
    const [ menu, page, content ] = [ '#menu', '#page', '#content_wrapper' ].map(id => document.querySelector(id));
    window.addEventListener("resize", event => {
        Common.resizeWindow(content, menu, page);
    });
    // page.css('overflow','hidden');
    Common.resizeAfterAllLoads();
});
