import roman2hiragana from './r2h.json' assert { type: 'json' }

const r2h = (roman) => {
	var i, iz, match, regex,
		hiragana = '', table = roman2hiragana;

	regex = new RegExp((function(table){
		var key,
		s = '^(?:';

		for (key in table) if (table.hasOwnProperty(key)) {
			s += key + '|';
		}
		return s + '(?:n(?![aiueo]|y[aiueo]|$))|' + '([^aiueon])\\1)';
	})(table));
	for (i = 0, iz = roman.length; i < iz; ++i) {
		if (match = roman.slice(i).match(regex)) {
			if (match[0] === 'n') {
				hiragana += 'ん';
			} else if (/^([^n])\1$/.test(match[0])) {
				hiragana += 'っ';
				--i;
			} else {
				hiragana += table[match[0]];
			}
			i += match[0].length - 1;
		} else {
			hiragana += roman[i];
		}
	}
	return hiragana;
}

export default r2h