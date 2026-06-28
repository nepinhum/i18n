module i18n

import strings

fn render_template(src string, left_delim string, right_delim string, data map[string]string) !string {
	left := if left_delim == '' { '{{' } else { left_delim }
	right := if right_delim == '' { '}}' } else { right_delim }
	mut out := strings.new_builder(src.len)
	mut pos := 0

	for pos < src.len {
		left_index := src.index_after(left, pos) or {
			out.write_string(src[pos..])
			break
		}

		out.write_string(src[pos..left_index])
		action_start := left_index + left.len
		right_index := src.index_after(right, action_start) or {
			return error('missing closing template delimiter')
		}

		action := src[action_start..right_index]
		key := template_action_key(action) or {
			return error('unsupported template action `${action}`')
		}
		value := data[key] or { return error('missing template data key `${key}`') }
		out.write_string(value)
		pos = right_index + right.len
	}

	return out.str()
}

fn template_action_key(action string) !string {
	if action.len < 2 || action[0] != `.` {
		return error('unsupported template action')
	}

	key := action[1..]
	for ch in key {
		if !is_template_key_char(ch) {
			return error('unsupported template action')
		}
	}

	return key
}

fn is_template_key_char(ch rune) bool {
	return (ch >= `a` && ch <= `z`) || (ch >= `A` && ch <= `Z`)
		|| (ch >= `0` && ch <= `9`) || ch == `_`
}
